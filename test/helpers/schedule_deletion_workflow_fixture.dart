import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'noop_alarm_reconciliation.dart';

// Real aggregate/SQLite/session/orchestration. Only storage and OS ports are
// controllable, and durable tests supply an actual FileAlarmJournalStore.
class DeletionWorkflowFixture {
  DeletionWorkflowFixture({
    AlarmJournalStore? journalStore,
    AppDatabase? database,
  }) : db = database ?? AppDatabase.forTesting(NativeDatabase.memory()) {
    owner = AlarmOperationCoordinator(
      gate,
      journal: AlarmOwnershipJournal(journalStore ?? MemoryAlarmJournalStore()),
    );
    sessions = makeSessions(owner);
    deletion = makeDeletion(owner, sessions);
  }
  final AppDatabase db;
  final gate = LocalDataOperationGate();
  late final recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
  late final aggregate = ScheduleAggregateRepositoryImpl(
    db,
    recurring,
    gate: gate,
    now: () => now,
  );
  final now = DateTime.utc(2029);
  final registry = DeletionRegistry();
  final scheduler = DeletionNative();
  final fallback = DeletionFallback();
  final timed = DeletionTimed();
  final early = DeletionEarly();
  final reconciliation = NoopAlarmReconciliation();
  late final AlarmOperationCoordinator owner;
  late final SchedulePreparationSessionUseCase sessions;
  late final DeleteScheduleUseCase deletion;
  SchedulePreparationSessionUseCase makeSessions(
    AlarmOperationCoordinator operations,
  ) => SchedulePreparationSessionUseCase(
    _UnusedSchedules(),
    _UnusedPreparation(),
    timed,
    early,
    CancelScheduleAlarmUseCase(
      registry,
      scheduler,
      fallback,
      operations: operations,
    ),
    reconciliation,
    operations: operations,
  );
  DeleteScheduleUseCase makeDeletion(
    AlarmOperationCoordinator operations,
    SchedulePreparationSessionUseCase session,
  ) => DeleteScheduleUseCase(
    aggregate,
    registry,
    scheduler,
    fallback,
    session,
    reconciliation,
    operations: operations,
  );
  Future<void> open() async => db.userDao.putUser(
    const UserEntity(id: 'local-profile', spareTime: Duration.zero, note: ''),
  );
  ScheduleEntity schedule([String id = 'one']) => ScheduleEntity(
    id: id,
    place: PlaceEntity(id: 'place-$id', placeName: 'private place'),
    scheduleName: 'private title',
    scheduleTime: DateTime.utc(2030, 1, 1, 10),
    timeZoneId: 'UTC',
    occurrenceOffsetSeconds: 0,
    moveTime: Duration.zero,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration.zero,
    scheduleNote: 'private note',
  );
  Future<ScheduleEntity> create([String id = 'one']) async {
    final value = schedule(id);
    await db.scheduleDao.createSchedule(value.toScheduleWithPlaceRow());
    await db.preparationScheduleDao.createPreparationSchedule(
      const PreparationEntity(preparationStepList: []),
      id,
    );
    return value;
  }

  Future<int> revision() async =>
      (await db.select(db.users).getSingle()).dataRevision;
  ScheduledAlarmRecord record(String id, int notification) =>
      ScheduledAlarmRecord(
        scheduleId: id,
        provider: AlarmProvider.localNotification,
        fallbackNotificationId: notification,
        alarmTime: DateTime.utc(2030),
        preparationStartTime: DateTime.utc(2030),
        scheduleFingerprint: 'private fingerprint',
        scheduleTitle: 'private title',
        payload: const {'note': 'private payload'},
      );
  Future<void> close() async {
    sessions.dispose();
    owner.dispose();
    gate.dispose();
    await db.close();
  }
}

class _UnusedSchedules extends Fake implements ScheduleRepository {}

class _UnusedPreparation extends Fake implements PreparationRepository {}

class DeletionRegistry extends Fake implements AlarmRegistryRepository {
  List<ScheduledAlarmRecord> records = [];
  int writes = 0;
  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => List.of(records);
  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> value) async {
    writes++;
    records = List.of(value);
  }
}

class DeletionNative extends Fake implements AlarmSchedulerService {
  final cancelled = <ScheduledAlarmRecord>[];
  Future<void> Function(ScheduledAlarmRecord)? onCancel;
  @override
  Future<void> cancelNativeAlarm(ScheduledAlarmRecord value) async {
    cancelled.add(value);
    await onCancel?.call(value);
  }
}

class DeletionFallback extends Fake
    implements FallbackAlarmNotificationService {
  final cancelled = <ScheduledAlarmRecord>[];
  Future<void> Function(ScheduledAlarmRecord)? onCancel;
  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord value) async {
    cancelled.add(value);
    await onCancel?.call(value);
  }
}

class DeletionTimed extends Fake implements TimedPreparationRepository {
  final snapshots = <String, TimedPreparationSnapshotEntity>{};
  final cleared = <String>[];
  Future<void> Function(String)? onClear;
  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String id,
  ) async => snapshots[id];
  @override
  Future<void> saveTimedPreparationSnapshot(
    String id,
    TimedPreparationSnapshotEntity value,
  ) async {
    snapshots[id] = value;
  }

  @override
  Future<void> clearTimedPreparation(String id) async {
    cleared.add(id);
    snapshots.remove(id);
    await onClear?.call(id);
  }
}

class DeletionEarly extends Fake implements EarlyStartSessionRepository {
  final values = <String, EarlyStartSessionEntity>{};
  final cleared = <String>[];
  @override
  Future<EarlyStartSessionEntity?> getSession(String id) async => values[id];
  @override
  Future<void> markStarted({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    values[scheduleId] = EarlyStartSessionEntity(
      scheduleId: scheduleId,
      startedAt: startedAt,
    );
  }

  @override
  Future<void> clear(String id) async {
    cleared.add(id);
    values.remove(id);
  }
}
