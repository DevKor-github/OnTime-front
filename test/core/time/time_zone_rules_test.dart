import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_value_validation.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:timezone/timezone.dart' as tz;

const ownedZoneName = 'Test/A10_Owned_Rules';

tz.Location fixedRules(int offsetMilliseconds) => tz.Location(
  ownedZoneName,
  <int>[],
  <int>[],
  [tz.TimeZone(offsetMilliseconds, isDst: false, abbreviation: 'A10')],
);

tz.Location changingRules() => tz.Location(
  ownedZoneName,
  [
    DateTime.utc(2040).millisecondsSinceEpoch,
    DateTime.utc(2050).millisecondsSinceEpoch,
  ],
  [0, 1],
  [
    const tz.TimeZone(0, isDst: false, abbreviation: 'A10A'),
    const tz.TimeZone(3600000, isDst: true, abbreviation: 'A10B'),
  ],
);

void main() {
  late Map<String, tz.Location> originalLocations;
  late tz.Location originalLocal;

  setUp(() {
    TimeZoneRules.ensureInitialized();
    originalLocations = Map.of(tz.timeZoneDatabase.locations);
    originalLocal = tz.local;
  });

  tearDown(() {
    // Mutations below touch only owned synthetic locations. Restore the same
    // global map and local pointer so no subsequent test inherits our fixtures.
    tz.timeZoneDatabase.locations
      ..clear()
      ..addAll(originalLocations);
    tz.setLocalLocation(originalLocal);
  });

  test('known and unknown lookup agree without inventing a UTC fallback', () {
    expect(TimeZoneRules.contains('Asia/Seoul'), isTrue);
    expect(TimeZoneRules.location('Asia/Seoul').name, 'Asia/Seoul');
    expect(TimeZoneRules.contains('UTC'), isTrue);
    expect(TimeZoneRules.location('UTC').name, 'UTC');
    expect(TimeZoneRules.contains('Not/A_Real_Zone'), isFalse);
    expect(
      () => TimeZoneRules.location('Not/A_Real_Zone'),
      throwsA(isA<tz.LocationNotFoundException>()),
    );
  });

  test('unchanged loaded content retains its identity', () {
    final before = TimeZoneRules.loadedIdentity;
    TimeZoneRules.ensureInitialized();
    TimeZoneRules.location('Asia/Seoul');
    expect(TimeZoneRules.loadedIdentity, before);
  });

  test(
    'backup validation shares the loaded rules instead of reinitializing them',
    () {
      tz.timeZoneDatabase.locations[ownedZoneName] = fixedRules(3600000);
      final before = TimeZoneRules.loadedIdentity;

      expect(
        () => BackupValueValidation.namedZone(ownedZoneName),
        returnsNormally,
      );
      expect(
        TimeZoneRules.location(ownedZoneName).zones.single.offset,
        3600000,
      );
      expect(TimeZoneRules.loadedIdentity, before);
    },
  );

  test(
    'replacing a location in the same map changes interpretation and identity',
    () {
      final map = tz.timeZoneDatabase.locations;
      map[ownedZoneName] = fixedRules(0);
      final before = TimeZoneRules.loadedIdentity;
      final value = ScheduleEntity(
        id: 'appointment',
        place: const PlaceEntity(id: 'place', placeName: 'Office'),
        scheduleName: 'Appointment',
        scheduleTime: DateTime.utc(2026, 9, 25, 12),
        timeZoneId: ownedZoneName,
        occurrenceOffsetSeconds: 0,
        moveTime: Duration.zero,
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
      );
      final first = ScheduleTimeResolver.resolve(
        value,
        nowUtc: DateTime.utc(2026, 9, 1),
      );
      expect(first.status, ScheduleTimeResolutionStatus.resolved);
      expect(first.instantUtc, DateTime.utc(2026, 9, 25, 12));

      // No lookup fake: the resolver sees the actual replaced registry entry.
      map[ownedZoneName] = fixedRules(3600000);
      expect(identical(map, tz.timeZoneDatabase.locations), isTrue);
      expect(TimeZoneRules.loadedIdentity, isNot(before));
      final second = ScheduleTimeResolver.resolve(
        value,
        nowUtc: DateTime.utc(2026, 9, 1),
      );
      expect(second.status, ScheduleTimeResolutionStatus.changed);
      expect(second.instantUtc, isNull);
      expect(second.proposedInstantUtc, DateTime.utc(2026, 9, 25, 11));
    },
  );

  test(
    'changing a transition instant in place invalidates the old rule identity',
    () {
      final location = changingRules();
      tz.timeZoneDatabase.locations[ownedZoneName] = location;
      final before = TimeZoneRules.loadedIdentity;
      final instant = DateTime.utc(2045).millisecondsSinceEpoch;
      expect(location.timeZone(instant).offset, 0);

      location.transitionAt[1] = DateTime.utc(2044).millisecondsSinceEpoch;
      expect(
        identical(TimeZoneRules.location(ownedZoneName), location),
        isTrue,
      );
      expect(location.timeZone(instant).offset, 3600000);
      expect(TimeZoneRules.loadedIdentity, isNot(before));
    },
  );

  test('changing the transition zone index in place changes rule identity', () {
    final location = changingRules();
    tz.timeZoneDatabase.locations[ownedZoneName] = location;
    final before = TimeZoneRules.loadedIdentity;
    final instant = DateTime.utc(2055).millisecondsSinceEpoch;
    expect(location.timeZone(instant).offset, 3600000);

    location.transitionZone[1] = 0;
    expect(location.timeZone(instant).offset, 0);
    expect(TimeZoneRules.loadedIdentity, isNot(before));
  });

  test(
    'changing a zone offset inside an existing location changes identity',
    () {
      final location = changingRules();
      tz.timeZoneDatabase.locations[ownedZoneName] = location;
      final before = TimeZoneRules.loadedIdentity;
      final instant = DateTime.utc(2055).millisecondsSinceEpoch;
      expect(location.timeZone(instant).offset, 3600000);

      location.zones[1] = const tz.TimeZone(
        7200000,
        isDst: true,
        abbreviation: 'A10B',
      );
      expect(location.timeZone(instant).offset, 7200000);
      expect(TimeZoneRules.loadedIdentity, isNot(before));
    },
  );

  test('equivalent content in a new object preserves rule identity', () {
    tz.timeZoneDatabase.locations[ownedZoneName] = changingRules();
    final before = TimeZoneRules.loadedIdentity;
    tz.timeZoneDatabase.locations[ownedZoneName] = changingRules();
    expect(TimeZoneRules.loadedIdentity, before);
  });

  test('map insertion order is not a rule change', () {
    final before = TimeZoneRules.loadedIdentity;
    final firstName = tz.timeZoneDatabase.locations.keys.first;
    final firstLocation = tz.timeZoneDatabase.locations.remove(firstName)!;
    tz.timeZoneDatabase.locations[firstName] = firstLocation;
    expect(TimeZoneRules.loadedIdentity, before);
  });

  test('removing a location invalidates its identity and lookup authority', () {
    tz.timeZoneDatabase.locations[ownedZoneName] = fixedRules(0);
    final before = TimeZoneRules.loadedIdentity;
    tz.timeZoneDatabase.locations.remove(ownedZoneName);
    expect(TimeZoneRules.loadedIdentity, isNot(before));
    expect(TimeZoneRules.contains(ownedZoneName), isFalse);
    expect(
      () => TimeZoneRules.location(ownedZoneName),
      throwsA(isA<tz.LocationNotFoundException>()),
    );
  });

  test('device local display zone does not change loaded rule identity', () {
    final before = TimeZoneRules.loadedIdentity;
    tz.setLocalLocation(TimeZoneRules.location('Asia/Seoul'));
    expect(TimeZoneRules.loadedIdentity, before);
    tz.setLocalLocation(TimeZoneRules.location('America/New_York'));
    expect(TimeZoneRules.loadedIdentity, before);
  });
}
