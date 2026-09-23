import Foundation

private final class FailedSyncDefaults: UserDefaults {
  override func synchronize() -> Bool { false }
}

private final class FailedReadbackDefaults: UserDefaults {
  override func synchronize() -> Bool { true }
  override func dictionary(forKey defaultName: String) -> [String: Any]? {
    ["scheduleId": "fixture-schedule", "fingerprint": "private-marker"]
  }
}

@main
struct AlarmLaunchPayloadTest {
  static func main() {
    let marker = "private-step-title-do-not-forward"
    let old: [String: Any] = [
      "scheduleId": "fixture-schedule", "fingerprint": marker,
      "title": marker, "body": marker, "alarmTime": "1234",
      "alarmLaunchAction": "startPreparation", "unknown": marker,
      "alarmLaunchPayloadVersion": "8", "type": "start-command"
    ]
    let expected = ["scheduleId": "fixture-schedule", "type": "schedule_alarm",
                    "alarmLaunchPayloadVersion": "9", "promptVariant": "alarm"]
    precondition(AlarmLaunchPayload.sanitize(old) == expected)
    precondition(AlarmLaunchPayload.sanitize(expected) == expected)
    for id: Any in [123, ["id"], "", "  ", "x\ny", "x\u{7f}y", String(repeating: "x", count: 513)] {
      precondition(AlarmLaunchPayload.sanitize(["scheduleId": id]) == nil)
    }
    precondition(AlarmLaunchPayload.sanitize(["scheduleId": "한글-🙂"]) != nil)
    let suite = "ontime-a11-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let key = "on_time_alarm_launch_payload"
    defaults.set("durable-sentinel", forKey: "unrelated")
    defaults.set(old, forKey: key)
    precondition(AlarmLaunchPayload.sanitizeStored(in: defaults, key: key))
    precondition(defaults.dictionary(forKey: key) as? [String: String] == expected)
    precondition(!String(describing: defaults.object(forKey: key)).contains(marker))
    precondition(AlarmLaunchPayload.sanitizeStored(in: defaults, key: key))
    for bad: Any in [marker, ["fingerprint": marker], ["scheduleId": 123, "fingerprint": marker]] {
      defaults.set(bad, forKey: key)
      precondition(AlarmLaunchPayload.sanitizeStored(in: defaults, key: key))
      precondition(defaults.object(forKey: key) == nil)
      precondition(defaults.string(forKey: "unrelated") == "durable-sentinel")
    }
    precondition(AlarmLaunchPayload.sanitizeStored(in: defaults, key: key))
    let failedSync = FailedSyncDefaults(suiteName: suite)!
    precondition(!AlarmLaunchPayload.sanitizeStored(in: failedSync, key: key))
    let failedReadback = FailedReadbackDefaults(suiteName: suite)!
    precondition(!AlarmLaunchPayload.sanitizeStored(in: failedReadback, key: key))
    print("iOS launch privacy contract passed (legacy, malformed, idempotent, stored cleanup)")
  }
}
