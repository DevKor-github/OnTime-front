import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:on_time_front/core/backup/backup_export_snapshot.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';

/// Actual FK SQLite, production aggregate writers and portable snapshot codec.
/// Memory staging and the unused timer store are not mobile/encryption proof.
class ScheduleDeletionFixture {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final gate = LocalDataOperationGate();
  DateTime now = DateTime.utc(2029);
  late final recurring = RecurringScheduleRepositoryImpl(db, now: () => now);
  late final aggregate = ScheduleAggregateRepositoryImpl(
    db,
    recurring,
    gate: gate,
    now: () => now,
  );
  late final schedules = ScheduleRepositoryImpl(
    database: db,
    recurringScheduleRepository: recurring,
    timedPreparationRepository: _UnusedTimerStore(),
    now: () => now,
  );

  Future<void> initialize() => db.userDao.putUser(
    const UserEntity(
      id: 'local-profile',
      spareTime: Duration.zero,
      note: 'retained profile',
      isOnboardingCompleted: true,
    ),
  );

  Future<void> close() async {
    await schedules.dispose();
    await db.close();
    gate.dispose();
  }

  PreparationEntity preparation(String marker) => PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: '$marker-first',
        preparationName: '$marker first',
        preparationTime: const Duration(minutes: 3),
        nextPreparationId: '$marker-last',
      ),
      PreparationStepEntity(
        id: '$marker-last',
        preparationName: '$marker last',
        preparationTime: const Duration(minutes: 2),
      ),
    ],
  );

  ScheduleEntity schedule(String id, {PlaceEntity? place, DateTime? at}) =>
      ScheduleEntity(
        id: id,
        place: place ?? PlaceEntity(id: 'place-$id', placeName: 'Place $id'),
        scheduleName: 'Name $id',
        scheduleNote: 'Note $id',
        scheduleTime: at ?? DateTime.utc(2030, 1, 2, 10),
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
        moveTime: Duration.zero,
        scheduleSpareTime: Duration.zero,
        preparationMode: SchedulePreparationMode.custom,
        isChanged: true,
        isStarted: false,
      );

  Future<void> create(String id, {PlaceEntity? place}) async {
    await aggregate.save(
      ScheduleFormSubmission(
        schedule: schedule(id, place: place),
        preparation: preparation(id),
        preparationChanged: true,
        baseline: await aggregate.newBaseline(),
        mutationId: 'create-$id',
      ),
      editing: false,
    );
  }

  Future<void> outcome(String id, ScheduleDoneStatus status) async {
    if (status == ScheduleDoneStatus.normalEnd ||
        status == ScheduleDoneStatus.lateEnd) {
      await schedules.finishSchedule(
        id,
        status == ScheduleDoneStatus.lateEnd ? 7 : 0,
      );
    } else if (status == ScheduleDoneStatus.abnormalEnd) {
      // Independent historical fixture, not a claim about the finish UI.
      await (db.update(db.schedules)..where((t) => t.id.equals(id))).write(
        SchedulesCompanion(
          doneStatus: Value(status.name),
          finishedAt: Value(DateTime.utc(2030, 1, 2, 11)),
        ),
      );
    }
  }

  Future<int> revision() async =>
      (await db.select(db.users).getSingle()).dataRevision;

  Future<({int eligible, int onTime})> score() async {
    final row = await db.select(db.users).getSingle();
    return (eligible: row.eligibleOutcomeCount, onTime: row.onTimeOutcomeCount);
  }

  Future<List<int>> exportBytes() async {
    final snapshot = await BackupExportSnapshot.create(
      db,
      cutoff: now,
      sourceAppVersion: '1.0+7',
      sourcePlatform: 'android',
      budget: BackupBudget(),
      stagingFactory: () async {
        final stage = AppDatabase.forTesting(NativeDatabase.memory());
        return RestoreStaging(stage, stage.close);
      },
    );
    try {
      return await snapshot.plaintext().expand((part) => part).toList();
    } finally {
      await snapshot.release();
    }
  }
}

class _UnusedTimerStore implements TimedPreparationRepository {
  @override
  Future<void> clearTimedPreparation(String scheduleId) async {}
  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String scheduleId,
  ) async => null;
  @override
  Future<void> saveTimedPreparationSnapshot(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  ) async {}
}
