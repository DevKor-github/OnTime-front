import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import SwiftUI
#endif

private let onTimeAlarmLaunchPayloadDefaultsKey = "on_time_alarm_launch_payload"

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nativeAlarmChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "on_time_front/native_alarm",
        binaryMessenger: controller.binaryMessenger
      )
      nativeAlarmChannel = channel
      channel.setMethodCallHandler { call, result in
        self.handleNativeAlarmCall(call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
    case "getLaunchPayload":
      result(takeStoredAlarmLaunchPayload())
    default:
      result(FlutterMethodNotImplemented)
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
            let scheduleId = args["scheduleId"] as? String,
            !scheduleId.isEmpty,
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

  private func cancelNativeAlarm(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      guard let args = call.arguments as? [String: Any],
            let scheduleId = args["scheduleId"] as? String,
            !scheduleId.isEmpty else {
        result(nil)
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
    result(nil)
  }

  private func takeStoredAlarmLaunchPayload() -> [String: String]? {
    let defaults = UserDefaults.standard
    guard let payload = defaults.dictionary(
      forKey: onTimeAlarmLaunchPayloadDefaultsKey
    ) as? [String: String] else {
      return nil
    }
    defaults.removeObject(forKey: onTimeAlarmLaunchPayloadDefaultsKey)
    return payload
  }

  private func alarmPayload(from args: [String: Any]) -> [String: String] {
    var payload: [String: String] = [:]
    if let rawPayload = args["payload"] as? [String: Any] {
      for (key, value) in rawPayload {
        payload[key] = "\(value)"
      }
    }
    payload["type"] = "schedule_alarm"
    payload["promptVariant"] = "alarm"
    if let scheduleId = args["scheduleId"] as? String {
      payload["scheduleId"] = scheduleId
    }
    if let alarmTime = int64Value(args["alarmTime"]) {
      payload["alarmTime"] = "\(alarmTime)"
    }
    if let preparationStartTime = int64Value(args["preparationStartTime"]) {
      payload["preparationStartTime"] = "\(preparationStartTime)"
    }
    return payload
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

  override func application(_ application: UIApplication, 
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken:Data){
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken:deviceToken)
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
private struct OpenScheduleAlarmIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Open OnTime"
  static var supportedModes: IntentModes = .foreground(.immediate)
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Payload")
  var encodedPayload: String

  init() {
    encodedPayload = "{}"
  }

  init(payload: [String: String]) {
    let data = try? JSONSerialization.data(withJSONObject: payload, options: [])
    encodedPayload = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
  }

  func perform() async throws -> some IntentResult {
    if let data = encodedPayload.data(using: .utf8),
       let payload = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
      UserDefaults.standard.set(payload, forKey: onTimeAlarmLaunchPayloadDefaultsKey)
      UserDefaults.standard.synchronize()
    }
    return .result()
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
