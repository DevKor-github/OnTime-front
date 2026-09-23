import Flutter
import UIKit

/// Only encrypted containers cross this channel; external URLs are never persisted.
final class BackupExportPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate,
  UIAdaptivePresentationControllerDelegate {
  private static let io = DispatchQueue(label: "ontime.backup-export.io", qos: .utility)
  private static var liveDirectories = Set<URL>() // Access only on io.
  private var active: Attempt?

  private final class Attempt {
    let id = UUID()
    let result: FlutterResult
    let directory: URL
    let file: URL
    var finishing = false
    weak var picker: UIDocumentPickerViewController?
    weak var scene: UIWindowScene?

    init(result: @escaping FlutterResult, directory: URL, file: URL) {
      self.result = result
      self.directory = directory
      self.file = file
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
            let children = try? FileManager.default.contentsOfDirectory(
              at: root, includingPropertiesForKeys: nil) else { return }
      for child in children where !Self.liveDirectories.contains(child) {
        try? FileManager.default.removeItem(at: child)
      }
    }
  }

  deinit { NotificationCenter.default.removeObserver(self) }

  @objc private func sceneDisconnected(_ notification: Notification) {
    guard let attempt = active, let scene = notification.object as? UIWindowScene,
          attempt.scene === scene else { return }
    finish(attempt, failed: true)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
    guard active == nil else {
      result(FlutterError(code: "export_busy", message: "A backup export is already in progress.", details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
          let bytes = args["encryptedBytes"] as? FlutterStandardTypedData,
          !bytes.data.isEmpty,
          let name = args["suggestedName"] as? String,
          !name.isEmpty, name.count <= 200, name.hasSuffix(".ontimebackup"),
          !name.contains("/"), !name.contains("\\") else {
      result(Self.failure())
      return
    }
    // Resolve only our own cache location here; actual disk work runs off the UI thread.
    guard let root = try? Self.exportRoot() else { result(Self.failure()); return }
    let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let attempt = Attempt(result: result, directory: directory, file: directory.appendingPathComponent(name))
    active = attempt
    Self.io.async {
      do {
        Self.liveDirectories.insert(directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
        try bytes.data.write(to: attempt.file, options: [.atomic, .completeFileProtection])
        let handle = try FileHandle(forWritingTo: attempt.file)
        do {
          try handle.synchronize()
          try handle.close()
        } catch {
          try? handle.close()
          throw error
        }
        guard try Data(contentsOf: attempt.file) == bytes.data else { throw ExportError.invalidContainer }
        DispatchQueue.main.async { self.present(attempt) }
      } catch {
        DispatchQueue.main.async { self.finish(attempt, failed: true) }
      }
    }
  }

  private func present(_ attempt: Attempt) {
    guard active === attempt, !attempt.finishing else { return }
    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }),
      var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      finish(attempt, failed: true)
      return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed else {
      finish(attempt, failed: true)
      return
    }
    let picker = UIDocumentPickerViewController(forExporting: [attempt.file], asCopy: true)
    picker.delegate = self
    picker.presentationController?.delegate = self
    attempt.picker = picker
    attempt.scene = scene
    presenter.present(picker, animated: true) {
      picker.presentationController?.delegate = self
      if picker.presentingViewController == nil { self.finish(attempt, failed: true) }
    }
    // UIKit may reject presentation without invoking its completion closure.
    DispatchQueue.main.async {
      if self.active === attempt, picker.presentingViewController == nil {
        self.finish(attempt, failed: true)
      }
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let attempt = active, attempt.picker === controller else { return }
    finish(attempt, outcome: "saved", failed: urls.count != 1)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let attempt = active, attempt.picker === controller else { return }
    finish(attempt, outcome: "cancelled")
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let attempt = active,
          attempt.picker === presentationController.presentedViewController else { return }
    finish(attempt, outcome: "cancelled")
  }

  private func finish(_ attempt: Attempt, outcome: String = "cancelled", failed: Bool = false) {
    guard active === attempt, !attempt.finishing else { return }
    attempt.finishing = true
    Self.io.async {
      // If removal fails, startup retries. A completed external copy remains a saved backup.
      try? FileManager.default.removeItem(at: attempt.directory)
      Self.liveDirectories.remove(attempt.directory)
      DispatchQueue.main.async {
        guard self.active === attempt else { return }
        self.active = nil
        attempt.result(failed ? Self.failure() : outcome)
      }
    }
  }

  private static func exportRoot() throws -> URL {
    try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: false)
      .appendingPathComponent("OnTimeBackupExports", isDirectory: true)
  }

  private static func failure() -> FlutterError {
    FlutterError(code: "export_failed", message: "Backup could not be saved. Please try again.", details: nil)
  }

  private enum ExportError: Error { case invalidContainer }
}
