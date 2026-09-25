import 'dart:async';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import '../../helpers/noop_alarm_reconciliation.dart';

class _Runtime extends Fake implements TimedPreparationRepository {}

class _Preparation extends Fake implements PreparationRepository {}

class _Early extends Fake implements EarlyStartSessionRepository {}

class _Cancel extends Fake implements CancelScheduleAlarmUseCase {}

// The real SQLite update has executed, but the surrounding transaction has not
// returned yet. Invalidating here tests rollback after all durable writes.
class _AfterRevision extends QueryInterceptor {
  bool armed = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final value = await executor.runUpdate(statement, args);
    if (armed && statement.contains('data_revision')) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return value;
  }
}

PreparationEntity _preparation([int minutes = 10]) => PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'prepare',
      preparationName: 'Synthetic preparation',
      preparationTime: Duration(minutes: minutes),
    ),
  ],
);

class _Fixture {
  _Fixture({this.barrier});
  final _AfterRevision? barrier;
  late AppDatabase db;
  late ScheduleRepositoryImpl repository;
  late SchedulePreparationSessionUseCase session;
  final operations = AlarmOperationCoordinator(LocalDataOperationGate.shared);
  final alarms = NoopAlarmReconciliation();
  final now = DateTime.utc(2029, 1, 1, 12);

  Future<void> open() async {
    final native = NativeDatabase.memory();
    db = AppDatabase.forTesting(
      barrier == null ? native : native.interceptWith(barrier!),
    );
    await db.userDao.putUser(
      const UserEntity(id: localProfileId, spareTime: Duration.zero, note: ''),
    );
    final runtime = _Runtime();
    repository = ScheduleRepositoryImpl(
      database: db,
      timedPreparationRepository: runtime,
      now: () => now,
    );
    await repository.createSchedule(
      ScheduleEntity(
        id: 'appointment',
        place: const PlaceEntity(id: 'place', placeName: 'Synthetic place'),
        scheduleName: 'Synthetic appointment',
        scheduleTime: DateTime.utc(2029, 1, 1, 12, 10),
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
        moveTime: Duration.zero,
        isChanged: true,
        isStarted: false,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
        preparationMode: SchedulePreparationMode.custom,
      ),
    );
    await db.preparationScheduleDao.createPreparationSchedule(
      _preparation(),
      'appointment',
    );
    session = SchedulePreparationSessionUseCase(
      repository,
      _Preparation(),
      runtime,
      _Early(),
      _Cancel(),
      alarms,
      operations: operations,
    );
  }

  Future<int> revision() async =>
      (await db.select(db.users).getSingle()).dataRevision;
  Future<ScheduleEntity> row() => repository.getScheduleById('appointment');
  Future<String> fingerprint({int preparationMinutes = 10}) async =>
      ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
        await row(),
        PreparationWithTimeEntity.fromPreparation(
          _preparation(preparationMinutes),
        ),
        timeResolution: ScheduleTimeResolution(
          status: ScheduleTimeResolutionStatus.resolved,
          instantUtc: DateTime.utc(2029, 1, 1, 12, 10),
        ),
      ).cacheFingerprint;
  Future<void> close() async {
    session.dispose();
    operations.dispose();
    await repository.dispose();
    await db.close();
  }
}

void main() {
  test(
    'actual queued start checks intent after the occupied alarm queue is released',
    () async {
      final f = _Fixture();
      await f.open();
      addTearDown(f.close);
      final original = await f.row();
      final before = await f.revision();
      final fingerprint = await f.fingerprint();
      var current = true;
      final entered = Completer<void>();
      final release = Completer<void>();
      final blocker = f.operations.run(f.operations.capture(), () async {
        entered.complete();
        await release.future;
      });
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      await entered.future;
      final pending = f.session.startSchedulePreparation(
        'appointment',
        isCurrent: () => current,
        expectedFingerprint: fingerprint,
      );
      final failure = expectLater(
        pending,
        throwsA(isA<ScheduleStartRejected>()),
      );
      await Future<void>.delayed(Duration.zero);
      current = false;
      release.complete();
      await blocker;
      await failure;
      expect(await f.row(), original);
      expect(await f.revision(), before);
      expect(f.alarms.callCount, 0);
      current = true;
      await f.session.startSchedulePreparation(
        'appointment',
        isCurrent: () => current,
        expectedFingerprint: fingerprint,
      );
      expect((await f.row()).isStarted, isTrue);
      expect((await f.row()).startedAt!.toUtc(), f.now);
      expect(await f.revision(), before + 1);
    },
  );

  test(
    'same-schedule queued replacement keeps its own guard and committed receipt',
    () async {
      final f = _Fixture();
      await f.open();
      addTearDown(f.close);
      final before = await f.revision();
      final fingerprint = await f.fingerprint();
      final entered = Completer<void>();
      final release = Completer<void>();
      final blocker = f.operations.run(f.operations.capture(), () async {
        entered.complete();
        await release.future;
      });
      addTearDown(() {
        if (!release.isCompleted) {
          release.complete();
        }
      });
      await entered.future;
      var oldCurrent = true;
      final old = f.session.startSchedulePreparation(
        'appointment',
        isCurrent: () => oldCurrent,
        expectedFingerprint: fingerprint,
      );
      final oldRejected = expectLater(
        old,
        throwsA(isA<ScheduleStartRejected>()),
      );
      oldCurrent = false;
      final replacement = f.session.startSchedulePreparation(
        'appointment',
        isCurrent: () => true,
        expectedFingerprint: fingerprint,
      );
      release.complete();
      await blocker;
      await oldRejected;
      final receipt = await replacement;
      expect(receipt.toUtc(), f.now);
      expect((await f.row()).startedAt!.toUtc(), receipt.toUtc());
      expect(await f.revision(), before + 1);
      expect(f.alarms.callCount, 0);
    },
  );

  test(
    'intent invalidation after actual SQL revision update rolls back the entire start and fresh retry commits once',
    () async {
      final barrier = _AfterRevision();
      final f = _Fixture(barrier: barrier);
      await f.open();
      addTearDown(f.close);
      addTearDown(() {
        if (!barrier.release.isCompleted) barrier.release.complete();
      });
      final original = await f.row();
      final before = await f.revision();
      final fingerprint = await f.fingerprint();
      var current = true;
      barrier.armed = true;
      final pending = f.repository.startSchedule(
        'appointment',
        isCurrent: () => current,
        expectedFingerprint: fingerprint,
      );
      final failure = expectLater(
        pending,
        throwsA(isA<ScheduleStartRejected>()),
      );
      await barrier.entered.future.timeout(const Duration(seconds: 5));
      current = false;
      barrier.release.complete();
      await failure;
      expect(await f.row(), original);
      expect((await f.row()).startedAt, isNull);
      expect((await f.row()).preparationFrozen, isFalse);
      expect(await f.revision(), before);
      current = true;
      await f.repository.startSchedule(
        'appointment',
        isCurrent: () => current,
        expectedFingerprint: fingerprint,
      );
      final started = await f.row();
      expect(started.isStarted, isTrue);
      expect(started.preparationFrozen, isTrue);
      expect(started.startedAt!.toUtc(), f.now);
      expect(await f.revision(), before + 1);
    },
  );

  for (final preparationOnly in [true, false]) {
    test(
      'actual ${preparationOnly ? 'preparation-only' : 'travel-time'} change rejects an old fingerprint even while the caller still considers its intent current',
      () async {
        final f = _Fixture();
        await f.open();
        addTearDown(f.close);
        final fingerprint = await f.fingerprint();
        if (preparationOnly) {
          await f.db.preparationScheduleDao.createPreparationSchedule(
            _preparation(11),
            'appointment',
          );
        } else {
          await f.repository.updateSchedule(
            (await f.row()).copyWith(moveTime: const Duration(minutes: 1)),
          );
        }
        final original = await f.row();
        final before = await f.revision();
        await expectLater(
          f.repository.startSchedule(
            'appointment',
            isCurrent: () => true,
            expectedFingerprint: fingerprint,
          ),
          throwsA(isA<ScheduleStartRejected>()),
        );
        expect(await f.row(), original);
        expect(await f.revision(), before);
        final fresh = await f.fingerprint(
          preparationMinutes: preparationOnly ? 11 : 10,
        );
        expect(fresh, isNot(fingerprint));
        await f.repository.startSchedule(
          'appointment',
          isCurrent: () => true,
          expectedFingerprint: fresh,
        );
        expect((await f.row()).isStarted, isTrue);
        expect(await f.revision(), before + 1);
      },
    );
  }
}
