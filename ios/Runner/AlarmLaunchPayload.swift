import Foundation

/// OS launch data is only a hint; Flutter validates the current DB before routing.
enum AlarmLaunchPayload {
  static func sanitize(_ source: [String: Any]?) -> [String: String]? {
    guard let id = source?["scheduleId"] as? String,
          !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          id.utf16.count <= 512,
          !id.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
      return nil
    }
    let identity = source?["storeIncarnation"] as? String
    if source?["storeIncarnation"] != nil {
      guard let identity, identity.range(of: "^[a-fA-F0-9-]{32,36}$", options: .regularExpression) != nil else { return nil }
    }
    var result = [
      "type": "schedule_alarm",
      "scheduleId": id,
      "alarmLaunchPayloadVersion": "10",
      "promptVariant": "alarm"
    ]
    if let identity { result["storeIncarnation"] = identity }
    return result
  }

  /// Rewrites old app-owned pending data even when DB startup subsequently fails.
  /// Never retain malformed values just because they do not cast to a dictionary.
  static func sanitizeStored(in defaults: UserDefaults, key: String) -> Bool {
    let clean = sanitize(defaults.dictionary(forKey: key))
    if let clean {
      defaults.set(clean, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
    guard defaults.synchronize() else { return false }
    if let clean {
      return defaults.dictionary(forKey: key) as? [String: String] == clean
    }
    return defaults.object(forKey: key) == nil
  }
}
