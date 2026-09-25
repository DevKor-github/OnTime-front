import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_export_snapshot.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/alarm_repository_impl.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';

// Actual repository -> SQLite snapshot -> streamed validator -> SQLite restore.
// Ordinary SQLite is explicit here; this is not SQLCipher/native-provider proof.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase source;
  late RecurringScheduleRepositoryImpl recurring;
  var now = DateTime.utc(2026, 1, 1);
  final start = DateTime.utc(2026, 1, 2, 10);
  final preparation = PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'original-step',
        preparationName: 'Prepare',
        preparationTime: const Duration(minutes: 10),
        nextPreparationId: null,
      ),
    ],
  );
  Future<List<ScheduleEntity>> rows(AppDatabase db) async =>
      (await db.scheduleDao.getScheduleList())
          .map((row) => row.toScheduleEntity())
          .toList()
        ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));

  Future<void> create({int count = 4}) => recurring.create(
    ScheduleEntity(
      id: 'series',
      place: const PlaceEntity(id: 'place', placeName: 'Office'),
      scheduleName: 'Work',
      scheduleTime: start,
      timeZoneId: 'UTC',
      occurrenceOffsetSeconds: 0,
      moveTime: Duration.zero,
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: Duration.zero,
      scheduleNote: '',
    ),
    preparation,
    RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      start: start,
      timeZoneId: 'UTC',
      count: count,
    ),
  );

  Future<BackupExportSnapshot> snapshot(AppDatabase db) async {
    final snapshot = await BackupExportSnapshot.create(
      db,
      cutoff: now,
      sourceAppVersion: 'a10-fixture',
      sourcePlatform: 'android',
      budget: BackupBudget(),
      stagingFactory: () async {
        final private = AppDatabase.forTesting(NativeDatabase.memory());
        return RestoreStaging(private, private.close);
      },
    );
    addTearDown(snapshot.release);
    return snapshot;
  }

  ScheduleRepositoryImpl schedules(AppDatabase db) {
    final value = ScheduleRepositoryImpl(
      database: db,
      timedPreparationRepository: _UnusedTimers(),
      now: () => now,
    );
    addTearDown(value.dispose);
    return value;
  }

  Future<AppDatabase> restore() async {
    final frozen = await snapshot(source);
    final checked = await BackupValidatedIngestion.validateOwnedSnapshot(
      plaintext: frozen.plaintext(),
      budget: BackupBudget(),
      createStore: (budget) async =>
          BackupIngestionStore.memoryForTesting(budget),
      nowUtc: now,
    );
    addTearDown(checked.release);
    final target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(target.close);
    await checked.materialize(target, pendingCleanup: false);
    await checked.validateReadBack(target, pendingCleanup: false);
    return target;
  }

  setUp(() async {
    now = DateTime.utc(2026, 1, 1);
    source = AppDatabase.forTesting(NativeDatabase.memory());
    recurring = RecurringScheduleRepositoryImpl(source, now: () => now);
    await source.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
  });
  tearDown(() => source.close());

  test(
    'following end preserves a frozen tail through portable validation',
    () async {
      await create();
      final before = await rows(source);
      now = DateTime.utc(2026, 1, 3, 9, 55);
      await schedules(source).startSchedule(before[1].id, startedAt: now);
      await recurring.delete(before[1], RecurringEditScope.following);
      final target = await restore();
      final restored = await rows(target);
      expect(restored.map((s) => s.id), before.take(2).map((s) => s.id));
      expect(restored.last.preparationFrozen, isTrue);
      expect(restored.last.startedAt?.toUtc(), now);
      expect(restored.last.retainedRecurringReference, isTrue);
      expect(restored.last.recurringSegmentId, before[1].recurringSegmentId);
      expect(
        restored.last.preparationDefinitionId,
        before[1].preparationDefinitionId,
      );
      expect(restored.last.isStarted, isFalse);
      final targetSchedules = schedules(target);
      final revision =
          (await target
                  .customSelect(
                    "SELECT data_revision FROM users WHERE id='local-profile'",
                  )
                  .getSingle())
              .read<int>('data_revision');
      await expectLater(
        targetSchedules.startSchedule(restored.last.id, startedAt: now),
        throwsA(isA<ScheduleStartRejected>()),
      );
      expect(
        (await target
                .customSelect(
                  "SELECT data_revision FROM users WHERE id='local-profile'",
                )
                .getSingle())
            .read<int>('data_revision'),
        revision,
      );
      final alarmCandidates =
          await AlarmRepositoryImpl(
            database: target,
            scheduleRepository: targetSchedules,
            preparationRepository: _UnusedPreparation(),
          ).getAlarmWindow(
            now.subtract(const Duration(days: 2)),
            DateTime.utc(2028),
          );
      expect(alarmCandidates.any((s) => s.id == restored.last.id), isFalse);

      await RecurringScheduleRepositoryImpl(
        target,
        now: () => now,
      ).materialize(start, DateTime.utc(2028));
      expect((await rows(target)).map((s) => s.id), restored.map((s) => s.id));
    },
  );

  test(
    'following edit keeps deleted-slot tombstone beyond old generation end',
    () async {
      await create(count: 10);
      final before = await rows(source);
      await recurring.delete(
        before.firstWhere((s) => s.scheduleTime.day == 6),
        RecurringEditScope.occurrence,
      );
      now = DateTime.utc(2026, 1, 5);
      final anchor = before.firstWhere((s) => s.scheduleTime.day == 5);
      await recurring.updateFollowing(
        anchor,
        anchor,
        preparation,
        RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          start: DateTime.utc(2026, 1, 5, 10),
          timeZoneId: 'UTC',
          weekdays: {1, 3, 5},
          count: 10,
        ),
      );
      final exclusions = await source
          .select(source.recurringScheduleExclusions)
          .get();
      expect(exclusions, isNotEmpty);
      final target = await restore();
      final restoredExclusions = await target
          .select(target.recurringScheduleExclusions)
          .get();
      expect(
        restoredExclusions.map((e) => e.toJson()),
        exclusions.map((e) => e.toJson()),
      );
      final retained = await rows(target);
      await RecurringScheduleRepositoryImpl(
        target,
        now: () => now,
      ).materialize(start, DateTime.utc(2028));
      expect((await rows(target)).map((s) => s.id), retained.map((s) => s.id));
      final exported = await snapshot(target);
      final portable = jsonDecode(
        utf8.decode(await exported.plaintext().expand((b) => b).toList()),
      );
      expect(portable['recurring']['exclusions'], isNotEmpty);
    },
  );

  for (final corruption in [
    'future-unprotected',
    'before-from',
    'count-overflow',
    'wrong-weekday',
    'dangling-definition',
    'wrong-owner',
    'duplicate-slot',
    'duplicate-ordinal',
    'ordinal-order',
    'calendar-ordinal-overflow',
    'invalid-calendar',
  ]) {
    test(
      'retained reference rejects $corruption without changing source',
      () async {
        await create();
        final initial = await rows(source);
        now = DateTime.utc(2026, 1, 3, 9, 55);
        await schedules(source).startSchedule(initial[1].id, startedAt: now);
        await recurring.delete(initial[1], RecurringEditScope.following);
        final frozen = await snapshot(source);
        final payload =
            jsonDecode(
                  utf8.decode(
                    await frozen.plaintext().expand((bytes) => bytes).toList(),
                  ),
                )
                as Map<String, dynamic>;
        final schedule = (payload['schedules'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((s) => s['id'] == initial[1].id);
        final segment = (payload['recurring']['segments'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((s) => s['id'] == schedule['recurringSegmentId']);
        switch (corruption) {
          case 'future-unprotected':
            schedule['preparationFrozen'] = false;
            schedule['startedAt'] = null;
          case 'before-from':
            schedule['recurringSlotKey'] = '2025-12-31T10:00:00.000Z';
          case 'count-overflow':
            schedule['recurringOrdinal'] = 999;
          case 'wrong-weekday':
            final rule =
                jsonDecode(segment['ruleJson'] as String)
                    as Map<String, dynamic>;
            rule['frequency'] = 'weekly';
            rule['weekdays'] = [1];
            segment['ruleJson'] = jsonEncode(rule);
          case 'dangling-definition':
            schedule['preparationDefinitionId'] = 'not-owned';
          case 'wrong-owner':
            final otherId = (payload['schedules'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((s) => s['id'] != schedule['id'])['id'];
            final definition =
                (payload['recurring']['definitions'] as List).first
                    as Map<String, dynamic>;
            payload['recurring']['definitions'].add({
              ...definition,
              'id': 'other-definition',
              'scope': 'occurrence',
              'ownerId': otherId,
            });
            final step =
                (payload['recurring']['steps'] as List).first
                    as Map<String, dynamic>;
            payload['recurring']['steps'].add({
              ...step,
              'id': 'other-step',
              'definitionId': 'other-definition',
            });
            schedule['preparationDefinitionId'] = 'other-definition';
            schedule['recurringOverrides'] = 'preparation';
          case 'duplicate-slot':
            payload['recurring']['exclusions'].add({
              'segmentId': schedule['recurringSegmentId'],
              'slotKey': schedule['recurringSlotKey'],
              'ordinal': schedule['recurringOrdinal'],
            });
          case 'duplicate-ordinal':
            payload['recurring']['exclusions'].add({
              'segmentId': schedule['recurringSegmentId'],
              'slotKey': '2026-01-04T10:00:00.000Z',
              'ordinal': schedule['recurringOrdinal'],
            });
          case 'ordinal-order':
            final other = (payload['schedules'] as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((s) => s['id'] != schedule['id']);
            other['recurringOrdinal'] = 2;
            schedule['recurringOrdinal'] = 1;
          case 'calendar-ordinal-overflow':
            schedule['recurringOrdinal'] = 4;
          case 'invalid-calendar':
            schedule['recurringSlotKey'] = '2026-02-30T10:00:00.000Z';
        }
        await expectLater(
          BackupValidatedIngestion.validateOwnedSnapshot(
            plaintext: Stream.value(utf8.encode(jsonEncode(payload))),
            budget: BackupBudget(),
            createStore: (budget) async =>
                BackupIngestionStore.memoryForTesting(budget),
            nowUtc: now,
          ),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'kind',
              BackupFailureKind.dataInvariant,
            ),
          ),
        );
        expect(
          (await rows(source)).map((s) => s.id),
          initial.take(2).map((s) => s.id),
        );
        expect((await rows(source)).last.preparationFrozen, isTrue);
      },
    );
  }
}

class _UnusedTimers implements TimedPreparationRepository {
  @override
  Future<void> clearTimedPreparation(String id) async {}
  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String id,
  ) async => null;
  @override
  Future<void> saveTimedPreparationSnapshot(
    String id,
    TimedPreparationSnapshotEntity value,
  ) async {}
}

class _UnusedPreparation implements PreparationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
