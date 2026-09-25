import Flutter
import UIKit
import CryptoKit
import Darwin

/// Only bounded encrypted chunks cross the channel. Provider URLs stay native.
final class BackupExportPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate,
  UIAdaptivePresentationControllerDelegate {
  private static let io = DispatchQueue(label: "ontime.backup-export.io", qos: .utility)
  private static var liveDirectories = Set<URL>() // io queue only
  private static let limit: Int64 = 72 * 1024 * 1024
  private var active: Attempt?
  private var lastReceipt: (String, [String: Any])?

  private final class Attempt {
    let id: String
    let directory: URL
    let file: URL
    private let lock = NSLock()
    private var interrupted = false
    var cancelled: Bool {
      lock.lock(); defer { lock.unlock() }; return interrupted
    }
    func cancel() { lock.lock(); interrupted = true; lock.unlock() }
    var busy = false
    var cleaning = false
    var directoryOwned = false
    var openHandles: [FileHandle] = [] // io queue; retain every unconfirmed close
    var registered = false
    var initialized = false
    var sealed = false
    var length: Int64 = 0
    var sequence: Int64 = 0
    var outcome: String?
    var providerTerminal = true // UI dismissal alone does not end a provider copy
    var pickerPending = false
    var pickerClosing = false
    var exportResult: FlutterResult?
    var cancelResults: [FlutterResult] = []
    var picker: UIDocumentPickerViewController?
    weak var scene: UIWindowScene?
    init(id: String, directory: URL, file: URL) {
      self.id = id; self.directory = directory; self.file = file
    }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = BackupExportPlugin()
    let channel = FlutterMethodChannel(name: "ontime/backup_export", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  override init() {
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(sceneDisconnected(_:)),
      name: UIScene.didDisconnectNotification, object: nil)
    Self.io.async {
      guard let root = try? Self.exportRoot(),
        let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        else { return }
      for child in children where !Self.liveDirectories.contains(child) {
        try? FileManager.default.removeItem(at: child)
      }
    }
  }
  deinit { NotificationCenter.default.removeObserver(self) }
  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    if let attempt = active { cancel(attempt, result: nil) }
  }
  @objc private func sceneDisconnected(_ notification: Notification) {
    guard let attempt = active, let scene = notification.object as? UIWindowScene,
      attempt.scene === scene else { return }
    cancel(attempt, result: nil)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    if call.method == "begin" {
      guard active == nil else { result(Self.failure("export_busy")); return }
      guard let name = args?["suggestedName"] as? String, !name.isEmpty,
        name.utf16.count <= 200, name.hasSuffix(".ontimebackup"),
        !name.contains("/"), !name.contains("\\"), !name.contains("\0"),
        let root = try? Self.exportRoot() else { result(Self.failure("export_invalid")); return }
      let id = UUID().uuidString
      let directory = root.appendingPathComponent(id, isDirectory: true)
      active = Attempt(id: id, directory: directory, file: directory.appendingPathComponent(name))
      result(id)
      return
    }
    let id = args?["handle"] as? String
    if call.method == "cancel", let id, let last = lastReceipt, id == last.0 {
      result(last.1); return
    }
    guard let attempt = active, id == attempt.id else { result(Self.failure("export_invalid")); return }
    if call.method == "cancel" { cancel(attempt, result: result); return }
    guard !attempt.cancelled, attempt.outcome == nil else { result(Self.failure("export_cancelled")); return }
    guard !attempt.busy, !attempt.cleaning, !attempt.pickerPending else {
      result(Self.failure("export_busy")); return
    }
    switch call.method {
    case "append":
      guard !attempt.sealed, let data = args?["bytes"] as? FlutterStandardTypedData,
        (1...65536).contains(data.data.count),
        let sequence = Self.integer(args?["sequence"]), sequence == attempt.sequence else {
        result(Self.failure("export_invalid")); return
      }
      guard Int64(data.data.count) <= Self.limit - attempt.length else {
        result(Self.failure("export_limit")); return
      }
      work(attempt, result: result) {
        try Self.checkCancelled(attempt)
        if !attempt.initialized {
          guard Self.liveDirectories.insert(attempt.directory).inserted else { throw ExportError.io }
          attempt.registered = true
          try FileManager.default.createDirectory(at: attempt.directory.deletingLastPathComponent(),
            withIntermediateDirectories: true)
          // Atomic exclusive creation: a colliding directory is never ours to remove.
          guard Darwin.mkdir(attempt.directory.path, 0o700) == 0 else { throw ExportError.io }
          attempt.directoryOwned = true
          var excluded = attempt.directory
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try excluded.setResourceValues(values)
          guard FileManager.default.createFile(atPath: attempt.file.path, contents: nil,
            attributes: [.protectionKey: FileProtectionType.complete]) else { throw ExportError.io }
          attempt.initialized = true
        }
        try Self.withHandle(attempt, try FileHandle(forWritingTo: attempt.file)) { handle in
          try handle.seekToEnd()
          try handle.write(contentsOf: data.data)
        }
        attempt.length += Int64(data.data.count)
        attempt.sequence += 1
      }
    case "seal":
      guard !attempt.sealed, attempt.initialized,
        let length = Self.integer(args?["length"]), (1...Self.limit).contains(length), length == attempt.length,
        let digest = args?["sha256"] as? String, digest.utf8.count == 64,
        digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
        result(Self.failure("export_invalid")); return
      }
      work(attempt, result: result, sealed: true) {
        try Self.withHandle(attempt, try FileHandle(forWritingTo: attempt.file)) { try $0.synchronize() }
        var hash = SHA256()
        var read: Int64 = 0
        try Self.withHandle(attempt, try FileHandle(forReadingFrom: attempt.file)) { reader in
          while true {
            try Self.checkCancelled(attempt)
            let chunk = try reader.read(upToCount: 65536) ?? Data()
            if chunk.isEmpty { break }
            guard Int64(chunk.count) <= length - read else { throw ExportError.io }
            hash.update(data: chunk)
            read += Int64(chunk.count)
          }
        }
        let actual = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard read == length, actual == digest else { throw ExportError.io }
      }
    case "export":
      guard attempt.sealed, attempt.exportResult == nil else { result(Self.failure("export_invalid")); return }
      attempt.exportResult = result
      present(attempt)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func work(_ attempt: Attempt, result: @escaping FlutterResult, sealed: Bool = false,
    block: @escaping () throws -> Void) {
    attempt.busy = true
    Self.io.async {
      var failed = false
      do { try block() } catch { failed = true }
      DispatchQueue.main.async {
        attempt.busy = false
        if failed || attempt.cancelled {
          if !attempt.cancelled { attempt.outcome = "failed" }
          result(Self.failure(attempt.cancelled ? "export_cancelled" : "export_io"))
        } else {
          if sealed { attempt.sealed = true }
          result(true)
        }
        self.finish(attempt)
      }
    }
  }

  private func present(_ attempt: Attempt) {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }),
      var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      attempt.outcome = "failed"; finish(attempt); return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed else {
      attempt.outcome = "failed"; finish(attempt); return
    }
    let picker = UIDocumentPickerViewController(forExporting: [attempt.file], asCopy: true)
    picker.delegate = self
    attempt.picker = picker
    attempt.scene = scene
    attempt.pickerPending = true
    attempt.providerTerminal = false
    presenter.present(picker, animated: true) {
      picker.presentationController?.delegate = self
    }
    // UIKit presentation is asynchronous. A missing presentingViewController
    // on the next main turn (or after UI dismissal) is not a provider terminal
    // receipt. Only the document delegate may authorize spool cleanup once the
    // picker has been handed the file; never infer it from UI timing.
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let attempt = active, attempt.picker === controller else { return }
    // The system reports a completed copy. Preserve it through cancellation/cleanup.
    attempt.providerTerminal = true
    if attempt.outcome != "saved" { attempt.outcome = urls.count == 1 ? "saved" : "failed" }
    dismiss(attempt)
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let attempt = active, attempt.picker === controller else { return }
    attempt.providerTerminal = true
    if attempt.outcome != "saved" { attempt.outcome = "cancelled" }
    dismiss(attempt)
  }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let attempt = active, attempt.picker === presentationController.presentedViewController else { return }
    if attempt.outcome == nil { attempt.outcome = "cancelled" }
    pickerTerminated(attempt)
  }

  private func cancel(_ attempt: Attempt, result: FlutterResult?) {
    if let result { attempt.cancelResults.append(result) }
    attempt.cancel()
    if attempt.outcome == nil { attempt.outcome = "cancelled" }
    // UIKit exposes no documented provider-copy cancellation acknowledgement
    // for a programmatic dismiss. Keep the system picker and spool until its
    // save/cancel delegate actually terminates the operation. This is cooperative
    // cancellation, never a timeout or scene teardown promoted to completion.
    if attempt.pickerPending && attempt.providerTerminal { dismiss(attempt) }
    finish(attempt)
  }
  private func dismiss(_ attempt: Attempt) {
    guard attempt.providerTerminal, !attempt.pickerClosing else { return }
    attempt.pickerClosing = true
    guard let picker = attempt.picker, picker.presentingViewController != nil else {
      pickerTerminated(attempt); return
    }
    picker.dismiss(animated: false) { self.pickerTerminated(attempt) }
  }
  private func pickerTerminated(_ attempt: Attempt) {
    attempt.pickerPending = false
    attempt.pickerClosing = false
    if attempt.providerTerminal { attempt.picker = nil }
    finish(attempt)
  }

  private func finish(_ attempt: Attempt) {
    guard active === attempt, attempt.outcome != nil, !attempt.busy,
      attempt.providerTerminal, !attempt.pickerPending, !attempt.cleaning else { return }
    guard attempt.exportResult != nil || !attempt.cancelResults.isEmpty || attempt.cancelled else { return }
    attempt.cleaning = true
    Self.io.async {
      var cleaned = false
      do {
        for handle in attempt.openHandles {
          do {
            try handle.close()
            attempt.openHandles.removeAll { $0 === handle }
          } catch { }
        }
        guard attempt.openHandles.isEmpty else { throw ExportError.io }
        if attempt.directoryOwned, FileManager.default.fileExists(atPath: attempt.directory.path) {
          try FileManager.default.removeItem(at: attempt.directory)
        }
        cleaned = !attempt.directoryOwned || !FileManager.default.fileExists(atPath: attempt.directory.path)
      } catch { }
      if cleaned && attempt.registered { Self.liveDirectories.remove(attempt.directory) }
      DispatchQueue.main.async {
        attempt.cleaning = false
        let receipt: [String: Any] = ["outcome": attempt.outcome ?? "cancelled", "cleanupUnconfirmed": !cleaned]
        let replies = attempt.cancelResults
        attempt.cancelResults.removeAll()
        let exportReply = attempt.exportResult
        attempt.exportResult = nil
        if cleaned {
          self.lastReceipt = (attempt.id, receipt)
          self.active = nil
        }
        exportReply?(receipt)
        replies.forEach { $0(receipt) }
      }
    }
  }

  private static func withHandle(_ attempt: Attempt, _ handle: FileHandle,
    block: (FileHandle) throws -> Void) throws {
    attempt.openHandles.append(handle)
    do {
      try block(handle)
      try handle.close()
      attempt.openHandles.removeAll { $0 === handle }
    } catch {
      // Keep ownership unless a retry actually confirms closure.
      do { try handle.close(); attempt.openHandles.removeAll { $0 === handle } } catch { }
      throw error
    }
  }
  private static func integer(_ value: Any?) -> Int64? {
    guard let number = value as? NSNumber,
      ["q", "i", "s", "l", "Q", "I"].contains(String(cString: number.objCType)),
      number.doubleValue >= 0, number.doubleValue <= Double(Int64.max) else { return nil }
    return number.int64Value
  }
  private static func checkCancelled(_ attempt: Attempt) throws {
    if attempt.cancelled { throw ExportError.io }
  }
  private static func exportRoot() throws -> URL {
    try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
      .appendingPathComponent("OnTimeBackupExports", isDirectory: true)
  }
  private static func failure(_ code: String) -> FlutterError {
    FlutterError(code: code, message: "Backup export did not complete. A partial file may remain at the selected location.", details: nil)
  }
  private enum ExportError: Error { case io }
}
