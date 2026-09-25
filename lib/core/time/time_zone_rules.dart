import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Shared initialization and content identity of the rules actually loaded.
abstract final class TimeZoneRules {
  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static List<String> get identifiers {
    ensureInitialized();
    return List.unmodifiable(
      tz.timeZoneDatabase.locations.keys.toList()..sort(),
    );
  }

  static bool contains(String identifier) {
    ensureInitialized();
    return identifier == 'UTC' ||
        tz.timeZoneDatabase.locations.containsKey(identifier);
  }

  static tz.Location location(String identifier) {
    ensureInitialized();
    return tz.getLocation(identifier);
  }

  /// Do not cache by map or Location identity: the library mutates both maps
  /// and rule arrays in place. Call at validation/claim boundaries, not ticks.
  static String get loadedIdentity {
    ensureInitialized();
    final names = tz.timeZoneDatabase.locations.keys.toList()..sort();
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              for (final name in names)
                [
                  name,
                  tz.timeZoneDatabase.locations[name]!.name,
                  tz.timeZoneDatabase.locations[name]!.transitionAt,
                  tz.timeZoneDatabase.locations[name]!.transitionZone,
                  for (final zone in tz.timeZoneDatabase.locations[name]!.zones)
                    [zone.offset, zone.isDst, zone.abbreviation],
                ],
            ]),
          ),
        )
        .toString();
  }
}
