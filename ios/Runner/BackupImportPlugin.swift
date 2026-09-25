import Flutter
import UIKit
import UniformTypeIdentifiers

/// Backup-only pull reader. All provider reads remain inside one coordinated
/// accessor, with transient security scope owned until the actual worker exits.
final class BackupImportPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate,
  UIAdaptivePresentationControllerDelegate {
  private var active: Attempt?
  private var lastClosed: String?
  private static let limit: Int64 = 72 * 1024 * 1024

  private final class Attempt {
    let id = UUID().uuidString
    let condition = NSCondition()
    var cancelled = false // condition-protected, including during a blocked read
    var request: (Int, FlutterResult)?
    var reading = false
    var started = false
    var terminal = false
    var closeGeneration = 0
    var cleanupFailed = false
    var picked = false
    var pickerTerminal = true // main-thread receipt, separate from worker terminal
    var pickerClosing = false
    var pickResult: FlutterResult? // main-thread only
    var closeResult: FlutterResult? // main-thread only
    weak var picker: UIDocumentPickerViewController?
    weak var scene: UIWindowScene?
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = BackupImportPlugin()
    let channel = FlutterMethodChannel(name: "ontime/backup_import", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  override init() {
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(sceneDisconnected(_:)),
      name: UIScene.didDisconnectNotification, object: nil)
  }
  deinit { NotificationCenter.default.removeObserver(self) }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    if let attempt = active { close(attempt, result: nil) }
  }

  @objc private func sceneDisconnected(_ notification: Notification) {
    guard let attempt = active, let scene = notification.object as? UIWindowScene,
      attempt.scene === scene else { return }
    close(attempt, result: nil)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "begin" {
      guard active == nil else { result(Self.failure("import_busy")); return }
      let attempt = Attempt()
      active = attempt
      result(attempt.id)
      return
    }
    let args = call.arguments as? [String: Any]
    let id = args?["handle"] as? String
    if call.method == "close", let id, id == lastClosed { result(true); return }
    guard let attempt = active, id == attempt.id else { result(Self.failure()); return }
    switch call.method {
    case "pick":
      guard !attempt.picked else { result(Self.failure()); return }
      attempt.picked = true
      attempt.pickResult = result
      present(attempt)
    case "read":
      guard let number = args?["maxBytes"] as? NSNumber,
        CFGetTypeID(number) != CFBooleanGetTypeID(),
        ["q", "i", "s", "l", "Q", "I"].contains(String(cString: number.objCType)),
        number.int64Value >= 1, number.int64Value <= 65536 else {
        result(Self.failure()); return
      }
      attempt.condition.lock()
      guard attempt.started, !attempt.cancelled, !attempt.terminal,
        !attempt.reading, attempt.request == nil else {
        attempt.condition.unlock(); result(Self.failure()); return
      }
      attempt.request = (number.intValue, result)
      attempt.condition.signal()
      attempt.condition.unlock()
    case "close": close(attempt, result: result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func present(_ attempt: Attempt) {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }),
      var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      finishPick(attempt, value: Self.failure()); return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed else {
      finishPick(attempt, value: Self.failure()); return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: false)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    attempt.picker = picker
    attempt.pickerTerminal = false
    attempt.scene = scene
    presenter.present(picker, animated: true) { picker.presentationController?.delegate = self }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let attempt = active, attempt.picker === controller, urls.count == 1 else { return }
    attempt.condition.lock()
    guard !attempt.cancelled, !attempt.started else { attempt.condition.unlock(); return }
    attempt.started = true
    attempt.condition.unlock()
    let url = urls[0] // Native-only, never persisted or returned over the channel.
    DispatchQueue.global(qos: .utility).async { self.readCoordinated(attempt, url: url) }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let attempt = active, attempt.picker === controller else { return }
    finishPick(attempt, value: nil)
  }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let picker = presentationController.presentedViewController as? UIDocumentPickerViewController else { return }
    documentPickerWasCancelled(picker)
  }

  private func readCoordinated(_ attempt: Attempt, url: URL) {
    let acquired = url.startAccessingSecurityScopedResource()
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var entered = false
    var workerError: FlutterError?
    coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
      entered = true
      var handle: FileHandle?
      do {
        attempt.condition.lock()
        let cancelled = attempt.cancelled
        attempt.condition.unlock()
        if cancelled { throw ImportError.cancelled }
        let values = try coordinatedURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        if values.isRegularFile == false { throw ImportError.io }
        let length = values.fileSize.flatMap { $0 >= 0 ? Int64($0) : nil }
        if let length, length > Self.limit { throw ImportError.limit }
        let opened = try FileHandle(forReadingFrom: coordinatedURL)
        handle = opened
        DispatchQueue.main.async { self.finishPick(attempt, value: ["length": length as Any? ?? NSNull()]) }
        var consumed: Int64 = 0
        var eof = false
        while true {
          attempt.condition.lock()
          while !attempt.cancelled && attempt.request == nil { attempt.condition.wait() }
          if attempt.cancelled {
            let request = attempt.request
            attempt.request = nil
            attempt.condition.unlock()
            if let request { Self.deliver(request.1, Self.failure("import_cancelled")) }
            break
          }
          let request = attempt.request!
          attempt.request = nil
          attempt.reading = true
          attempt.condition.unlock()
          var response: Any
          do {
            let size = min(request.0, Int(Self.limit - consumed + 1))
            let data = eof ? Data() : (try opened.read(upToCount: size) ?? Data())
            if Int64(data.count) > Self.limit - consumed { throw ImportError.limit }
            consumed += Int64(data.count)
            eof = data.isEmpty
            response = ["bytes": FlutterStandardTypedData(bytes: data), "eof": eof]
          } catch ImportError.limit { response = Self.failure("import_limit") }
          catch { response = Self.failure() }
          attempt.condition.lock()
          let cancelled = attempt.cancelled
          attempt.reading = false
          attempt.condition.unlock()
          Self.deliver(request.1, cancelled ? Self.failure("import_cancelled") : response)
        }
      } catch ImportError.cancelled { workerError = Self.failure("import_cancelled") }
      catch ImportError.limit { workerError = Self.failure("import_limit") }
      catch { workerError = Self.failure() }
      // Closing belongs to this accessor too. Never release coordination/scope
      // on a timer while a provider operation has not returned.
      var closed = false
      while !closed {
        attempt.condition.lock()
        let generation = attempt.closeGeneration
        attempt.condition.unlock()
        do { try handle?.close(); closed = true }
        catch {
          attempt.condition.lock(); attempt.cleanupFailed = true; attempt.condition.unlock()
          DispatchQueue.main.async {
            let reply = attempt.closeResult
            attempt.closeResult = nil
            reply?(Self.failure())
          }
          // Keep handle, coordinated accessor and security scope owned while a
          // failed close is retried. No new import can replace this attempt.
          attempt.condition.lock()
          while attempt.closeGeneration == generation { attempt.condition.wait() }
          attempt.cleanupFailed = false
          attempt.condition.unlock()
        }
      }
    }
    if acquired { url.stopAccessingSecurityScopedResource() }
    if !entered || coordinationError != nil { workerError = Self.failure() }
    attempt.condition.lock()
    attempt.terminal = true
    let pending = attempt.request
    attempt.request = nil
    attempt.condition.unlock()
    if let pending { Self.deliver(pending.1, workerError ?? Self.failure("import_cancelled")) }
    let failure = workerError
    DispatchQueue.main.async {
      if let failure { self.finishPick(attempt, value: failure) }
      self.finishClose(attempt)
    }
  }

  private func finishPick(_ attempt: Attempt, value: Any?) {
    guard active === attempt else { return }
    let callback = attempt.pickResult
    attempt.pickResult = nil
    attempt.condition.lock(); let cancelled = attempt.cancelled; attempt.condition.unlock()
    callback?(cancelled ? Self.failure("import_cancelled") : value)
  }

  private func close(_ attempt: Attempt, result: FlutterResult?) {
    guard attempt.closeResult == nil else { result?(Self.failure("import_busy")); return }
    attempt.closeResult = result
    attempt.condition.lock()
    attempt.cancelled = true
    attempt.closeGeneration += 1
    let started = attempt.started
    if !started { attempt.terminal = true }
    attempt.condition.broadcast() // Independent of the blocked coordination/read worker.
    attempt.condition.unlock()
    finishPick(attempt, value: Self.failure("import_cancelled"))
    if !attempt.pickerClosing {
      attempt.pickerClosing = true
      if let picker = attempt.picker, picker.presentingViewController != nil {
        picker.dismiss(animated: true) {
          attempt.pickerTerminal = true
          self.finishClose(attempt)
        }
      } else {
        attempt.pickerTerminal = true
        finishClose(attempt)
      }
    } else { finishClose(attempt) }
  }

  private func finishClose(_ attempt: Attempt) {
    attempt.condition.lock()
    let terminal = attempt.terminal
    let failed = attempt.cleanupFailed
    let cancelled = attempt.cancelled
    attempt.condition.unlock()
    guard cancelled && terminal && attempt.pickerTerminal else { return }
    let reply = attempt.closeResult
    attempt.closeResult = nil
    // A close failure does not claim the reader was cleaned up. The owner stays
    // retained for explicit cleanup reporting; no subsequent import is admitted.
    guard !failed else { reply?(Self.failure()); return }
    if active === attempt { active = nil }
    lastClosed = attempt.id
    reply?(true)
  }

  private enum ImportError: Error { case io, limit, cancelled }
  private static func failure(_ code: String = "import_io") -> FlutterError {
    FlutterError(code: code, message: "Backup input could not be read.", details: nil)
  }
  private static func deliver(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }
}
