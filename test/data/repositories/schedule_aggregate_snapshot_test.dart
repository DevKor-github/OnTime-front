import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/restore_staging_fixture.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'dart:convert';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/sodium_test_loader.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/alarm_repository_impl.dart';
import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'schedule_aggregate_repository_test.dart' show schedule, prep;

class _BlockedRead extends QueryInterceptor {
  String needle = 'FROM "preparation_schedules"';
  bool armed = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (armed && statement.contains(needle)) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return executor.runSelect(statement, args);
  }
}

class _Schedules extends Fake implements ScheduleRepository {}

class _Preparations extends Fake implements PreparationRepository {}

class _Profile extends Fake implements UserRepository {}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final reader in ['edit', 'planning']) {
    test(
      '$reader snapshot cannot combine old schedule with new preparation',
      () async {
        final barrier = _BlockedRead();
        final db = AppDatabase.forTesting(
          NativeDatabase.memory().interceptWith(barrier),
        );
        final recurring = RecurringScheduleRepositoryImpl(
          db,
          now: () => DateTime.utc(2029),
        );
        final repo = ScheduleAggregateRepositoryImpl(
          db,
          recurring,
          gate: LocalDataOperationGate(),
          now: () => DateTime.utc(2029),
        );
        try {
          await db.userDao.putUser(
            const UserEntity(
              id: 'local-profile',
              spareTime: Duration.zero,
              note: '',
            ),
          );
          await repo.save(
            ScheduleFormSubmission(
              schedule: schedule(),
              preparation: prep(),
              preparationChanged: true,
              mutationId: 'create',
              baseline: await repo.newBaseline(),
            ),
            editing: false,
          );
          final baseline = await repo.readForEdit('one');
          final update = ScheduleFormSubmission(
            schedule: baseline.schedule.copyWith(scheduleName: 'New'),
            preparation: prep(30),
            preparationChanged: true,
            originalSchedule: baseline.schedule,
            mutationId: 'edit',
            baseline: baseline.baseline,
          );
          final alarms = AlarmRepositoryImpl(
            database: db,
            scheduleRepository: _Schedules(),
            preparationRepository: _Preparations(),
          );
          barrier.armed = true;
          final reading = reader == 'edit'
              ? repo
                    .readForEdit('one')
                    .then(
                      (s) => (
                        s.schedule.scheduleName,
                        s.preparation.totalDuration.inMinutes,
                      ),
                    )
              : alarms
                    .getAlarmWindow(DateTime.utc(2029), DateTime.utc(2031))
                    .then(
                      (s) => (
                        s.single.scheduleName,
                        s.single.preparation.totalDuration.inMinutes,
                      ),
                    );
          await barrier.entered.future;
          final writing = repo.save(update, editing: true);
          barrier.release.complete();
          expect(await reading, ('Meeting', 10));
          await writing;
          final after = await repo.readForEdit('one');
          expect(
            (
              after.schedule.scheduleName,
              after.preparation.totalDuration.inMinutes,
            ),
            ('New', 30),
          );
        } finally {
          await db.close();
        }
      },
    );
  }
  test(
    'file database close/reopen with new gate verifies committed receipt',
    () async {
      final dir = await Directory.systemTemp.createTemp('a08-receipt-');
      final file = File('${dir.path}/local.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      var recurring = RecurringScheduleRepositoryImpl(
        db,
        now: () => DateTime.utc(2029),
      );
      var repo = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: '',
        ),
      );
      final draft = ScheduleFormSubmission(
        schedule: schedule(),
        preparation: prep(),
        preparationChanged: true,
        mutationId: 'persisted-intent',
        baseline: await repo.newBaseline(),
      );
      await repo.save(draft, editing: false);
      final revision = (await db.select(db.users).getSingle()).dataRevision;
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      recurring = RecurringScheduleRepositoryImpl(
        db,
        now: () => DateTime.utc(2029),
      );
      repo = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      try {
        expect((await repo.save(draft, editing: false)).changed, isFalse);
        expect((await db.select(db.users).getSingle()).dataRevision, revision);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'real preparation watch sees committed aggregate and never rolled back value',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final recurring = RecurringScheduleRepositoryImpl(
        db,
        now: () => DateTime.utc(2029),
      );
      final repo = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        now: () => DateTime.utc(2029),
      );
      final preparations = PreparationRepositoryImpl(
        preparationLocalDataSource: PreparationLocalDataSourceImpl(
          appDatabase: db,
        ),
        userRepository: _Profile(),
        database: db,
      );
      final values = <int>[];
      final subscription = preparations.preparationStream.listen((v) {
        if (v['one'] != null) values.add(v['one']!.totalDuration.inMinutes);
      });
      try {
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        final created = preparations.preparationStream.firstWhere(
          (v) => v['one']?.totalDuration.inMinutes == 10,
        );
        await repo.save(
          ScheduleFormSubmission(
            schedule: schedule(),
            preparation: prep(),
            preparationChanged: true,
            mutationId: 'create',
            baseline: await repo.newBaseline(),
          ),
          editing: false,
        );
        await created;
        final old = await repo.readForEdit('one');
        final draft = ScheduleFormSubmission(
          schedule: old.schedule,
          preparation: prep(99),
          preparationChanged: true,
          mutationId: 'edit',
          baseline: old.baseline,
          originalSchedule: old.schedule,
        );
        await db.customStatement(
          "CREATE TRIGGER fail_revision BEFORE UPDATE OF data_revision ON users BEGIN SELECT RAISE(ABORT,'failed'); END",
        );
        await expectLater(repo.save(draft, editing: true), throwsA(anything));
        await db.customStatement('DROP TRIGGER fail_revision');
        // A subsequent committed dependency write drains the serial real watch reader.
        // It cannot repair or hide an earlier invalid emission, retained in values.
        final drained = preparations.preparationStream
            .skip(1)
            .firstWhere((v) => v['one']?.totalDuration.inMinutes == 10);
        await db.preparationUserDao.createPreparationUser(
          prep(7),
          'local-profile',
        );
        await drained;
        expect(
          values,
          isNot(contains(99)),
          reason: 'rollback must not publish the attempted preparation',
        );
        final committed = preparations.preparationStream.firstWhere(
          (v) => v['one']?.totalDuration.inMinutes == 99,
        );
        await repo.save(draft, editing: true);
        await committed;
        expect(values.first, 10);
        expect(values.where((v) => v == 99).length, 1);
      } finally {
        await subscription.cancel();
        await preparations.dispose();
        await db.close();
      }
    },
  );
  test(
    'template and definition trigger versions wake actual dependent schedule watch',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final recurring = RecurringScheduleRepositoryImpl(
        db,
        now: () => DateTime.utc(2029),
      );
      final repo = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        now: () => DateTime.utc(2029),
      );
      try {
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        await db.preparationTemplateDao.put(
          id: 'template',
          name: 'Template',
          preparation: prep(8),
          now: DateTime.utc(2029),
        );
        await repo.save(
          ScheduleFormSubmission(
            schedule: schedule().copyWith(
              preparationMode: SchedulePreparationMode.template,
              preparationTemplateId: 'template',
            ),
            preparation: prep(8),
            preparationChanged: false,
            mutationId: 'template-create',
            baseline: await repo.newBaseline(),
          ),
          editing: false,
        );
        final initial = await repo.readForEdit('one');
        final observed = db.scheduleDao
            .watchScheduleList()
            .asyncMap((_) => repo.readForEdit('one'))
            .firstWhere((s) => s.baseline.version != initial.baseline.version);
        await db.preparationTemplateDao.put(
          id: 'template',
          name: 'Template',
          preparation: prep(9),
          now: DateTime.utc(2029),
        );
        expect((await observed).preparation.totalDuration.inMinutes, 9);
        final rule = RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: DateTime.utc(2031, 1, 1, 10),
          timeZoneId: 'UTC',
          count: 2,
        );
        await repo.save(
          ScheduleFormSubmission(
            schedule: schedule('series').copyWith(scheduleTime: rule.start),
            preparation: prep(),
            preparationChanged: true,
            recurrenceRule: rule,
            mutationId: 'series-create',
            baseline: await repo.newBaseline(),
          ),
          editing: false,
        );
        final row = (await db.scheduleDao.getScheduleList()).firstWhere(
          (r) => r.schedule.recurringSegmentId != null,
        );
        final before = await repo.readForEdit(row.schedule.id);
        final updated = db.scheduleDao
            .watchScheduleList()
            .asyncMap((_) => repo.readForEdit(row.schedule.id))
            .firstWhere(
              (s) => s.baseline.rootVersion != before.baseline.rootVersion,
            );
        await (db.update(db.preparationDefinitionSteps)..where(
              (t) =>
                  t.definitionId.equals(row.schedule.preparationDefinitionId!),
            ))
            .write(
              const PreparationDefinitionStepsCompanion(minutes: Value(11)),
            );
        final after = await updated;
        expect(after.preparation.totalDuration.inMinutes, 11);
        expect(after.baseline.version, isNot(before.baseline.version));
      } finally {
        await db.close();
      }
    },
  );

  test(
    'new draft reads default preparation and revision in one real transaction',
    () async {
      final barrier = _BlockedRead()..needle = 'FROM "preparation_users"';
      final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(barrier),
      );
      final repo = ScheduleAggregateRepositoryImpl(
        db,
        RecurringScheduleRepositoryImpl(db),
        gate: LocalDataOperationGate(),
      );
      try {
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        await db.preparationUserDao.createPreparationUser(
          prep(7),
          'local-profile',
        );
        final revision = (await db.select(db.users).getSingle()).dataRevision;
        barrier.armed = true;
        final pending = repo.newDraft();
        await barrier.entered.future;
        final writing = db.transaction(() async {
          await db.preparationUserDao.createPreparationUser(
            prep(9),
            'local-profile',
          );
          await db.userDao.markDurableDataChanged('local-profile');
        });
        barrier.release.complete();
        final draft = await pending;
        expect(draft.preparation.totalDuration.inMinutes, 7);
        expect(draft.baseline.revision, revision);
        await writing;
        final current = await repo.newDraft();
        expect(current.preparation.totalDuration.inMinutes, 9);
        expect(current.baseline.revision, revision + 1);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'following receipt survives file close reopen and deletion of original occurrence',
    () async {
      final dir = await Directory.systemTemp.createTemp('a08-following-');
      final file = File('${dir.path}/db.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      var recurring = RecurringScheduleRepositoryImpl(
        db,
        now: () => DateTime.utc(2029),
      );
      var repo = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: '',
        ),
      );
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 1, 1, 10),
        timeZoneId: 'UTC',
        count: 3,
      );
      await repo.save(
        ScheduleFormSubmission(
          schedule: schedule('series'),
          preparation: prep(),
          preparationChanged: true,
          recurrenceRule: rule,
          mutationId: 'create',
          baseline: await repo.newBaseline(),
        ),
        editing: false,
      );
      final before = await repo.readForEdit(
        (await db.scheduleDao.getScheduleList())[1].schedule.id,
      );
      final intent = ScheduleFormSubmission(
        schedule: before.schedule.copyWith(scheduleName: 'New series'),
        preparation: before.preparation,
        preparationChanged: false,
        originalSchedule: before.schedule,
        baseline: before.baseline,
        mutationId: 'split',
        recurringScope: RecurringEditScope.following,
        recurrenceRule: rule.withStartAndEnd(
          start: before.schedule.scheduleTime,
          count: rule.count,
          until: rule.until,
        ),
      );
      await repo.save(intent, editing: true);
      expect(
        await (db.select(
          db.schedules,
        )..where((t) => t.id.equals(before.schedule.id))).getSingleOrNull(),
        isNull,
      );
      final revision = (await db.select(db.users).getSingle()).dataRevision;
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      recurring = RecurringScheduleRepositoryImpl(
        db,
        now: () => DateTime.utc(2029),
      );
      repo = ScheduleAggregateRepositoryImpl(
        db,
        recurring,
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      try {
        expect((await repo.save(intent, editing: true)).changed, isFalse);
        expect((await db.select(db.users).getSingle()).dataRevision, revision);
        expect(await db.select(db.schedules).get(), hasLength(3));
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'real encrypted backup cutoff cannot mix concurrent aggregate commit',
    () async {
      final barrier = _BlockedRead();
      final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(barrier),
      );
      final repo = ScheduleAggregateRepositoryImpl(
        db,
        RecurringScheduleRepositoryImpl(db),
        gate: LocalDataOperationGate(),
        now: () => DateTime.utc(2029),
      );
      final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
      final service = BackupService(
        db,
        _Metadata(),
        NoopAlarmCleanup(),
        ingestionFactory: memoryBackupIngestion,
        processingOwner: testBackupProcessingOwner(),
        stagingFactory: memoryRestoreStaging,
        runtimeIdentity: RestoreRuntimeIdentity(),
        cleanupPlatform: noPlatformRestoreCleanup,
        crypto: crypto,
        operationGate: LocalDataOperationGate(),
      );
      try {
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
          ),
        );
        await repo.save(
          ScheduleFormSubmission(
            schedule: schedule(),
            preparation: prep(),
            preparationChanged: true,
            mutationId: 'create',
            baseline: await repo.newBaseline(),
          ),
          editing: false,
        );
        final snapshot = await repo.readForEdit('one');
        final revision = (await db.select(db.users).getSingle()).dataRevision;
        barrier.armed = true;
        final reading = service.createEncryptedBackup(
          'portable backup password',
        );
        await barrier.entered.future;
        final writing = repo.save(
          ScheduleFormSubmission(
            schedule: snapshot.schedule.copyWith(scheduleName: 'New'),
            preparation: prep(30),
            preparationChanged: true,
            mutationId: 'edit',
            baseline: snapshot.baseline,
            originalSchedule: snapshot.schedule,
          ),
          editing: true,
        );
        barrier.release.complete();
        final bytes = await reading;
        await writing;
        final data =
            jsonDecode(
                  utf8.decode(
                    await crypto.decrypt(
                      container: bytes,
                      password: 'portable backup password',
                    ),
                  ),
                )
                as Map<String, dynamic>;
        expect(data['dataRevision'], revision);
        expect(data['schedules'].single['name'], 'Meeting');
        expect(data['schedulePreparations']['one'].single['minutes'], 10);
        final actual = await repo.readForEdit('one');
        expect(actual.schedule.scheduleName, 'New');
        expect(actual.preparation.totalDuration.inMinutes, 30);
      } finally {
        await db.close();
      }
    },
  );
}
