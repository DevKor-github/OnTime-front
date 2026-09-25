import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_snapshot_validation.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/notification_route_payload.dart';

ScheduleWithPreparationEntity fixture({
  String name = 'secret:|준비',
  String id = 'step',
  int move = 10,
  int spare = 3,
  int minute = 0,
  int duration = 5,
  String? next,
  String zone = 'UTC',
}) => ScheduleWithPreparationEntity(
  id: 'schedule',
  place: const PlaceEntity(id: 'place', placeName: 'private place'),
  scheduleName: 'private title',
  scheduleNote: 'private note',
  scheduleTime: DateTime.utc(2026, 9, 23, 10, minute),
  timeZoneId: zone,
  // This fixture represents a known running instant. Legacy null history is
  // separately covered by civil_legacy_runtime_migration_test.
  occurrenceOffsetSeconds: zone == 'Asia/Seoul' ? 32400 : 0,
  moveTime: Duration(minutes: move),
  scheduleSpareTime: Duration(minutes: spare),
  isChanged: false,
  isStarted: true,
  preparation: PreparationWithTimeEntity(
    preparationStepList: [
      PreparationStepWithTimeEntity(
        id: id,
        preparationName: name,
        preparationTime: Duration(minutes: duration),
        nextPreparationId: next,
      ),
    ],
  ),
);

void main() {
  test('identity separates timing, ordered shape, content and delimiters', () {
    final original = fixture();
    expect(original.cacheFingerprint, fixture().cacheFingerprint);
    expect(original.cacheFingerprint, isNot(contains('secret')));
    expect(fixture(name: 'different').timingIdentity, original.timingIdentity);
    expect(
      fixture(name: 'different').preparationShapeIdentity,
      isNot(original.preparationShapeIdentity),
    );
    expect(
      fixture(move: 11).preparationShapeIdentity,
      original.preparationShapeIdentity,
    );
    expect(
      fixture(id: 'a:b', name: 'c').cacheFingerprint,
      isNot(fixture(id: 'a', name: 'b:c').cacheFingerprint),
    );
  });
  test(
    'every identity-affecting edit invalidates progress without mutating data',
    () {
      final original = fixture();
      final snapshot = TimedPreparationSnapshotEntity(
        preparation: original.preparation,
        savedAt: DateTime.utc(2026),
        scheduleFingerprint: original.cacheFingerprint,
      );
      for (final changed in [
        fixture(name: 'renamed'),
        fixture(id: 'new'),
        fixture(move: 11),
        fixture(spare: 4),
        fixture(minute: 1),
        fixture(duration: 6),
        fixture(next: 'other'),
        fixture(zone: 'Asia/Seoul'),
      ]) {
        expect(validatePreparationSnapshot(snapshot, changed), isNull);
        expect(changed.isStarted, isTrue);
      }
    },
  );
  test(
    'minimal progress hydrates names/durations from current source only',
    () {
      final schedule = fixture();
      final minimal = TimedPreparationSnapshotEntity(
        contentOmitted: true,
        savedAt: DateTime.utc(2026),
        scheduleFingerprint: schedule.cacheFingerprint,
        preparation: const PreparationWithTimeEntity(
          preparationStepList: [
            PreparationStepWithTimeEntity(
              id: 'step',
              preparationName: '',
              nextPreparationId: null,
              preparationTime: Duration.zero,
              elapsedTime: Duration(minutes: 2),
            ),
          ],
        ),
      );
      final hydrated = validatePreparationSnapshot(minimal, schedule)!;
      expect(hydrated.preparation.currentStep!.preparationName, 'secret:|준비');
      expect(
        hydrated.preparation.currentStep!.preparationTime,
        const Duration(minutes: 5),
      );
      expect(
        hydrated.preparation.currentStep!.elapsedTime,
        const Duration(minutes: 2),
      );
    },
  );
  test('legacy exact fingerprint additionally requires all step fields', () {
    final schedule = fixture();
    final legacy = TimedPreparationSnapshotEntity(
      preparation: schedule.preparation,
      savedAt: DateTime.utc(2026),
      scheduleFingerprint: schedule.legacyCacheFingerprint,
    );
    expect(
      validatePreparationSnapshot(legacy, schedule)!.scheduleFingerprint,
      schedule.cacheFingerprint,
    );
    expect(
      validatePreparationSnapshot(
        legacy.copyWith(preparation: fixture(id: 'other').preparation),
        schedule,
      ),
      isNull,
    );
    expect(
      validatePreparationSnapshot(
        legacy.copyWith(scheduleFingerprint: ''),
        schedule,
      ),
      isNull,
    );
  });
  test(
    'legacy launch becomes a minimal versioned route, never a start command',
    () {
      expect(
        minimalScheduleRoutePayload({
          'type': 'schedule_alarm',
          'scheduleId': 'schedule',
          'alarmLaunchPayloadVersion': '8',
          'scheduleFingerprint': 'secret',
          'alarmLaunchAction': 'startPreparation',
          'title': 'secret',
        }),
        {
          'type': 'schedule_alarm',
          'scheduleId': 'schedule',
          'alarmLaunchPayloadVersion': '10',
          'promptVariant': 'alarm',
        },
      );
      for (final bad in ['', '  ', '\n', 'a\u0000b', 'x' * 513, 42]) {
        expect(
          minimalScheduleRoutePayload({
            'type': 'schedule_alarm',
            'scheduleId': bad,
          }),
          isEmpty,
        );
      }
    },
  );
}
