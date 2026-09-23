import Flutter
import UIKit
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import SwiftUI
#endif

private let onTimeAlarmLaunchPayloadDefaultsKey = "on_time_alarm_launch_payload"
private let onTimeAlarmLaunchURLScheme = "ontime"
private let onTimeAlarmLaunchURLHost = "alarm"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static weak var current: AppDelegate?
  private var nativeAlarmChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    Self.current = self
    _ = AlarmLaunchPayload.sanitizeStored(
      in: .standard, key: onTimeAlarmLaunchPayloadDefaultsKey
    )
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OnTimeBackupExport") {
      BackupExportPlugin.register(with: registrar)
    }
    let channel = FlutterMethodChannel(
      name: "on_time_front/native_alarm",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    nativeAlarmChannel = channel
    channel.setMethodCallHandler { call, result in
      self.handleNativeAlarmCall(call, result: result)
    }
  }

  private func handleNativeAlarmCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCapabilities":
      result(nativeAlarmCapabilities())
    case "checkPermission":
      result(checkNativeAlarmPermission())
    case "requestPermission":
      requestNativeAlarmPermission(result: result)
    case "scheduleNativeAlarm":
      scheduleNativeAlarm(call, result: result)
    case "cancelNativeAlarm":
      cancelNativeAlarm(call, result: result)
    case "getPendingNativeAlarms":
      getPendingNativeAlarms(call, result: result)
    case "sanitizeStoredLaunchPayload":
      let cleaned = AlarmLaunchPayload.sanitizeStored(
        in: .standard, key: onTimeAlarmLaunchPayloadDefaultsKey
      )
      result(cleaned ? nil : FlutterError(
        code: "privacyCleanupFailed",
        message: "Could not confirm pending launch cleanup.", details: nil
      ))
    case "getLaunchPayload":
      result(takeStoredAlarmLaunchPayload())
    case "getLocalTimeZone":
      result(TimeZone.current.identifier)
    case "excludeFromBackup":
      excludeFromBackup(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func excludeFromBackup(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.isEmpty else {
      result(FlutterError(code: "invalidArguments", message: "Missing path", details: nil))
      return
    }
    var url = URL(fileURLWithPath: path)
    do {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
      result(nil)
    } catch {
      result(FlutterError(
        code: "platformError",
        message: "Could not exclude local data from backup: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if Self.handleAlarmLaunchURL(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  private func nativeAlarmCapabilities() -> [String: Any] {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      return [
        "supportsNativeAlarm": true,
        "nativeAlarmProvider": "iosAlarmKit",
        "fallbackProvider": "localNotification"
      ]
    }
    #endif
    return [
      "supportsNativeAlarm": false,
      "nativeAlarmProvider": "none",
      "fallbackProvider": "localNotification"
    ]
  }

  private func checkNativeAlarmPermission() -> String {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      return alarmPermissionWireValue(AlarmManager.shared.authorizationState)
    }
    #endif
    return "unsupported"
  }

  private func requestNativeAlarmPermission(result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      Task {
        do {
          let state = try await AlarmManager.shared.requestAuthorization()
          deliverFlutterResult(result, alarmPermissionWireValue(state))
        } catch {
          deliverFlutterResult(result, FlutterError(
            code: "platformError",
            message: "AlarmKit authorization failed: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
      return
    }
    #endif
    result("unsupported")
  }

  private func scheduleNativeAlarm(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      guard let args = call.arguments as? [String: Any],
            let route = AlarmLaunchPayload.sanitize(args),
            let scheduleId = route["scheduleId"],
            let alarmTimeMillis = int64Value(args["alarmTime"]) else {
        result(FlutterError(
          code: "invalidArguments",
          message: "Missing scheduleId or alarmTime",
          details: nil
        ))
        return
      }

      let alarmDate = Date(timeIntervalSince1970: TimeInterval(alarmTimeMillis) / 1000)
      guard alarmDate > Date() else {
        result(FlutterError(
          code: "invalidArguments",
          message: "Cannot schedule a past alarm",
          details: nil
        ))
        return
      }

      guard AlarmManager.shared.authorizationState == .authorized else {
        result(FlutterError(
          code: "permissionDenied",
          message: "AlarmKit permission is not authorized",
          details: nil
        ))
        return
      }

      let title = args["title"] as? String ?? "OnTime"
      let body = args["body"] as? String ?? "It is time to get ready."
      let payload = alarmPayload(from: args)
      let alarmId = deterministicAlarmUUID(scheduleId)

      Task {
        do {
          let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: AlarmButton(
              text: "Stop",
              textColor: .white,
              systemImageName: "stop.circle"
            ),
            secondaryButton: AlarmButton(
              text: "Open",
              textColor: .white,
              systemImageName: "arrow.up.forward.app"
            ),
            secondaryButtonBehavior: .custom
          )
          let presentation = AlarmPresentation(alert: alert)
          let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: OnTimeAlarmMetadata(
              scheduleId: scheduleId,
              title: title,
              body: body
            ),
            tintColor: Color.orange
          )
          let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(alarmDate),
            attributes: attributes,
            secondaryIntent: OpenScheduleAlarmIntent(payload: payload)
          )
          _ = try await AlarmManager.shared.schedule(
            id: alarmId,
            configuration: configuration
          )
          deliverFlutterResult(result, nil)
        } catch {
          deliverFlutterResult(result, FlutterError(
            code: "platformError",
            message: "AlarmKit scheduling failed: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
      return
    }
    #endif
    result(FlutterError(
      code: "unsupported",
      message: "AlarmKit native scheduling is not available in this build or OS version.",
      details: nil
    ))
  }

  private func getPendingNativeAlarms(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      guard let args = call.arguments as? [String: Any],
            let scheduleIds = args["scheduleIds"] as? [String] else {
        result(FlutterError(code: "invalidArguments", message: "Missing schedule IDs", details: nil))
        return
      }
      do {
        // Do not invert UUID hashes or infer ownership from arbitrary UUIDs.
        let known = Dictionary(scheduleIds.map { (deterministicAlarmUUID($0), $0) },
                               uniquingKeysWith: { first, _ in first })
        let alarms = try AlarmManager.shared.alarms
        let matched = alarms.compactMap { known[$0.id] }
        result(["source": "iosAlarmKit", "scheduleIds": matched,
                "unmappedCount": alarms.count - matched.count])
      } catch {
        result(FlutterError(code: "observationFailed", message: "AlarmKit registrations could not be read.", details: nil))
      }
      return
    }
    #endif
    result(FlutterError(code: "unsupported", message: "AlarmKit observation is unavailable.", details: nil))
  }

  private func cancelNativeAlarm(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      guard let args = call.arguments as? [String: Any],
            let scheduleId = args["scheduleId"] as? String,
            !scheduleId.isEmpty else {
        result(FlutterError(code: "invalidArguments", message: "Missing schedule ID", details: nil))
        return
      }
      do {
        try AlarmManager.shared.cancel(id: deterministicAlarmUUID(scheduleId))
        result(nil)
      } catch {
        result(FlutterError(
          code: "platformError",
          message: "AlarmKit cancellation failed: \(error.localizedDescription)",
          details: nil
        ))
      }
      return
    }
    #endif
    result(FlutterError(
      code: "unsupported",
      message: "AlarmKit cancellation cannot be confirmed on this build or OS version.",
      details: nil
    ))
  }

  private func takeStoredAlarmLaunchPayload() -> [String: String]? {
    let defaults = UserDefaults.standard
    let payload = AlarmLaunchPayload.sanitize(
      defaults.dictionary(forKey: onTimeAlarmLaunchPayloadDefaultsKey)
    )
    defaults.removeObject(forKey: onTimeAlarmLaunchPayloadDefaultsKey)
    return payload
  }

  static func handleAlarmLaunchURL(_ url: URL) -> Bool {
    guard url.scheme == onTimeAlarmLaunchURLScheme,
          url.host == onTimeAlarmLaunchURLHost else { return false }
    var values: [String: Any] = [:]
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
      // Duplicate identity parameters are ambiguous, not last-value-wins.
      let identities = (components.queryItems ?? []).filter { $0.name == "scheduleId" }
      if identities.count == 1 { values["scheduleId"] = identities.first?.value }
    }
    guard let payload = AlarmLaunchPayload.sanitize(values) else {
      UserDefaults.standard.removeObject(forKey: onTimeAlarmLaunchPayloadDefaultsKey)
      return true
    }
    storeAlarmLaunchPayload(payload)
    current?.notifyFlutterAlarmLaunch(payload)
    return true
  }

  fileprivate static func alarmLaunchURL(payload: [String: String]) -> URL? {
    guard let clean = AlarmLaunchPayload.sanitize(payload) else { return nil }
    var components = URLComponents()
    components.scheme = onTimeAlarmLaunchURLScheme
    components.host = onTimeAlarmLaunchURLHost
    components.queryItems = clean.keys.sorted().map { key in
      URLQueryItem(name: key, value: clean[key])
    }
    return components.url
  }

  fileprivate static func storeAlarmLaunchPayload(_ payload: [String: String]) {
    let defaults = UserDefaults.standard
    if let clean = AlarmLaunchPayload.sanitize(payload) {
      defaults.set(clean, forKey: onTimeAlarmLaunchPayloadDefaultsKey)
    } else {
      defaults.removeObject(forKey: onTimeAlarmLaunchPayloadDefaultsKey)
    }
    defaults.synchronize()
  }

  private func notifyFlutterAlarmLaunch(_ payload: [String: String]) {
    guard let clean = AlarmLaunchPayload.sanitize(payload) else { return }
    DispatchQueue.main.async {
      self.nativeAlarmChannel?.invokeMethod("alarmLaunch", arguments: clean)
    }
  }

  private func alarmPayload(from args: [String: Any]) -> [String: String] {
    // Provider time/title/body and nested payload are not route instructions.
    return AlarmLaunchPayload.sanitize(args) ?? [:]
  }

  private func int64Value(_ value: Any?) -> Int64? {
    if let number = value as? NSNumber {
      return number.int64Value
    }
    if let int = value as? Int {
      return Int64(int)
    }
    if let string = value as? String {
      return Int64(string)
    }
    return nil
  }

  private func deliverFlutterResult(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }

}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct OnTimeAlarmMetadata: AlarmMetadata {
  let scheduleId: String
  let title: String
  let body: String
}

@available(iOS 26.0, *)
public struct OpenScheduleAlarmIntent: LiveActivityIntent {
  public static var title: LocalizedStringResource = "Open OnTime"
  public static var supportedModes: IntentModes = .foreground(.immediate)
  public static var openAppWhenRun: Bool = true

  @Parameter(title: "Payload")
  public var encodedPayload: String

  public init() {
    encodedPayload = "{}"
  }

  public init(payload: [String: String]) {
    let data = try? JSONSerialization.data(withJSONObject: AlarmLaunchPayload.sanitize(payload) ?? [:], options: [])
    encodedPayload = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
  }

  public func perform() async throws -> some IntentResult & OpensIntent {
    if let data = encodedPayload.data(using: .utf8),
       let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let payload = AlarmLaunchPayload.sanitize(raw) {
      #if DEBUG
      NSLog("OnTime AlarmKit Open intent invoked with a routing hint")
      #endif
      await AppDelegate.storeAlarmLaunchPayload(payload)
      if let url = await AppDelegate.alarmLaunchURL(payload: payload) {
        return .result(opensIntent: OpenURLIntent(url))
      }
    }
    #if DEBUG
    NSLog("OnTime AlarmKit Open intent invoked without a valid payload")
    #endif
    return .result(opensIntent: OpenURLIntent(URL(string: "\(onTimeAlarmLaunchURLScheme)://\(onTimeAlarmLaunchURLHost)")!))
  }
}

@available(iOS 26.0, *)
private func alarmPermissionWireValue(_ state: AlarmManager.AuthorizationState) -> String {
  switch state {
  case .authorized:
    return "granted"
  case .denied:
    return "denied"
  case .notDetermined:
    return "notDetermined"
  @unknown default:
    return "unsupported"
  }
}

private func deterministicAlarmUUID(_ scheduleId: String) -> UUID {
  var firstHash: UInt64 = 1469598103934665603
  var secondHash: UInt64 = 1099511628211

  for byte in scheduleId.utf8 {
    firstHash = (firstHash ^ UInt64(byte)) &* 1099511628211
  }
  for byte in scheduleId.utf8.reversed() {
    secondHash = (secondHash ^ UInt64(byte)) &* 1099511628211
  }

  var bytes = [UInt8](repeating: 0, count: 16)
  for index in 0..<8 {
    bytes[index] = UInt8((firstHash >> UInt64(index * 8)) & 0xff)
    bytes[index + 8] = UInt8((secondHash >> UInt64(index * 8)) & 0xff)
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x50
  bytes[8] = (bytes[8] & 0x3f) | 0x80

  return UUID(uuid: (
    bytes[0], bytes[1], bytes[2], bytes[3],
    bytes[4], bytes[5], bytes[6], bytes[7],
    bytes[8], bytes[9], bytes[10], bytes[11],
    bytes[12], bytes[13], bytes[14], bytes[15]
  ))
}
#endif
