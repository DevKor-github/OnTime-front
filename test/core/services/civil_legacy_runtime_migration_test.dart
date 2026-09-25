import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/services/runtime_privacy_migration.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'unresolved rows do not prevent a normal legacy run from migrating',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final examples = [
        (
          id: 'normal',
          civil: DateTime.utc(2026, 9, 23, 10),
          zone: 'UTC',
          offset: 0,
        ),
        (
          id: 'unknown',
          civil: DateTime.utc(2026, 9, 23, 10),
          zone: 'Missing/Zone',
          offset: 0,
        ),
        (
          id: 'gap',
          civil: DateTime.utc(2026, 3, 8, 2, 30),
          zone: 'America/New_York',
          offset: null,
        ),
        (
          id: 'ambiguous',
          civil: DateTime.utc(2026, 11, 1, 1, 30),
          zone: 'America/New_York',
          offset: null,
        ),
        (
          id: 'past-null',
          civil: DateTime.utc(2025, 9, 23, 10),
          zone: 'UTC',
          offset: null,
        ),
      ];
      final prefs = await SharedPreferences.getInstance();
      for (final example in examples) {
        await database.scheduleDao.createSchedule(
          ScheduleEntity(
            id: example.id,
            place: const PlaceEntity(id: 'place', placeName: 'Place'),
            scheduleName: example.id,
            scheduleNote: '',
            scheduleTime: example.civil,
            timeZoneId: example.zone,
            occurrenceOffsetSeconds: example.offset,
            moveTime: const Duration(minutes: 10),
            scheduleSpareTime: const Duration(minutes: 3),
            isChanged: false,
            isStarted: false,
          ).toScheduleWithPlaceRow(),
        );
        await prefs.setString(
          'preparation_with_time_${example.id}',
          jsonEncode({
            'savedAt': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
            'startedAt': null,
            'scheduleFingerprint':
                '2026-09-23T10:00:00.000|UTC|0|600000|180000|step:Prepare:300000:|',
            'actionEvents': <Object>[],
            'steps': [
              {
                'id': 'step',
                'name': 'Prepare',
                'time': 300000,
                'nextId': null,
                'elapsed': 120000,
                'isDone': false,
              },
            ],
          }),
        );
        await prefs.setString('early_start_session_${example.id}', '{}');
      }
      final before =
          (await database
                  .customSelect('SELECT * FROM schedules ORDER BY id')
                  .get())
              .map((row) => row.data)
              .toList();
      final snapshots = PreparationWithTimeLocalDataSourceImpl();
      await RuntimePrivacyMigration(
        _DatabaseSchedules(database),
        _Preparations(),
        snapshots,
        AlarmRegistryLocalDataSourceImpl(),
        cleanPlatform: () async {},
        now: () => DateTime.utc(2026, 1, 1),
      ).run();
      final normal = (await snapshots.loadPreparation('normal'))!;
      expect(normal.requiresConfirmation, isFalse);
      expect(
        normal.preparation.preparationStepList.single.elapsedTime,
        const Duration(minutes: 2),
      );
      for (final example in examples.skip(1)) {
        expect(
          prefs.containsKey('preparation_with_time_${example.id}'),
          isFalse,
        );
        expect(prefs.containsKey('early_start_session_${example.id}'), isFalse);
      }
      final after =
          (await database
                  .customSelect('SELECT * FROM schedules ORDER BY id')
                  .get())
              .map((row) => row.data)
              .toList();
      expect(after, before);
    },
  );

  test('snapshot storage failure is not classified as a time review', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preparation_with_time_unknown', '{}');
    await expectLater(
      RuntimePrivacyMigration(
        _DatabaseSchedules(database),
        _Preparations(),
        _UnreadableSnapshots(),
        AlarmRegistryLocalDataSourceImpl(),
        cleanPlatform: () async {},
      ).run(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'original failure',
          'storage unavailable',
        ),
      ),
    );
  });

  for (final changedCivil in [false, true]) {
    test(
      'old no-Z progress through SQLite migration; changed=$changedCivil',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await database.scheduleDao.createSchedule(
          ScheduleEntity(
            id: 'schedule',
            place: const PlaceEntity(id: 'place', placeName: 'Place'),
            scheduleName: 'Schedule',
            scheduleNote: '',
            scheduleTime: DateTime.utc(2026, 9, 23, changedCivil ? 11 : 10),
            timeZoneId: 'UTC',
            occurrenceOffsetSeconds: 0,
            moveTime: const Duration(minutes: 10),
            scheduleSpareTime: const Duration(minutes: 3),
            isChanged: false,
            isStarted: true,
            preparationFrozen: true,
            startedAt: DateTime.utc(2026, 9, 23, 9, 42),
          ).toScheduleWithPlaceRow(),
        );
        final row = await database.scheduleDao.getScheduleById('schedule');
        expect(row.schedule.scheduleTime.isUtc, isTrue);
        final prefs = await SharedPreferences.getInstance();
        // Exact bytes of the pre-carrier converter's local civil serializer.
        // Deliberately not produced by the new fingerprint getter.
        const oldFingerprint =
            '2026-09-23T10:00:00.000|UTC|0|600000|180000|step:Prepare:300000:|';
        await prefs.setString(
          'preparation_with_time_schedule',
          jsonEncode({
            'savedAt': DateTime.utc(2026, 9, 23, 9, 44).millisecondsSinceEpoch,
            'startedAt': DateTime.utc(
              2026,
              9,
              23,
              9,
              42,
            ).millisecondsSinceEpoch,
            'scheduleFingerprint': oldFingerprint,
            'actionEvents': <Object>[],
            'steps': [
              {
                'id': 'step',
                'name': 'Prepare',
                'time': 300000,
                'nextId': null,
                'elapsed': 120000,
                'isDone': false,
              },
            ],
          }),
        );
        final snapshots = PreparationWithTimeLocalDataSourceImpl();
        await RuntimePrivacyMigration(
          _DatabaseSchedules(database),
          _Preparations(),
          snapshots,
          AlarmRegistryLocalDataSourceImpl(),
          cleanPlatform: () async {},
        ).run();
        final migrated = (await snapshots.loadPreparation('schedule'))!;
        expect(
          ScheduleWithPreparationEntity.isCurrentIdentity(
            migrated.scheduleFingerprint,
          ),
          isTrue,
        );
        expect(migrated.requiresConfirmation, changedCivil);
        expect(
          migrated.preparation.preparationStepList.single.elapsedTime,
          Duration(minutes: changedCivil ? 0 : 2),
        );
        if (!changedCivil) {
          expect(migrated.startedAt!.toUtc(), DateTime.utc(2026, 9, 23, 9, 42));
        }
        final raw = prefs.getString('preparation_with_time_schedule')!;
        expect(raw, isNot(contains('Prepare')));
        expect(raw, isNot(contains(oldFingerprint)));
        expect(
          (await database.scheduleDao.getScheduleById(
            'schedule',
          )).schedule.scheduleTime,
          row.schedule.scheduleTime,
        );
      },
    );
  }
}

class _DatabaseSchedules implements ScheduleRepository {
  _DatabaseSchedules(this.database);
  final AppDatabase database;
  @override
  Future<ScheduleEntity> getScheduleById(String id) async =>
      (await database.scheduleDao.getScheduleById(id)).toScheduleEntity();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preparations implements PreparationLocalDataSource {
  @override
  Future<PreparationEntity> getPreparationByScheduleId(String id) async =>
      const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'step',
            preparationName: 'Prepare',
            preparationTime: Duration(minutes: 5),
            nextPreparationId: null,
          ),
        ],
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnreadableSnapshots extends PreparationWithTimeLocalDataSourceImpl {
  @override
  Future<TimedPreparationSnapshotEntity?> loadPreparation(
    String scheduleId,
  ) async => throw StateError('storage unavailable');
}
