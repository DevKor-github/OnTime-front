import '../../helpers/isolated_alarm_owner.dart';
import 'dart:async';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/entities/delivery_observation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/alarm_registry_repository_impl.dart';
import 'package:on_time_front/data/repositories/alarm_repository_impl.dart';
import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlarmOperationCoordinator isolatedOwner;
  setUp(() {
    isolatedOwner = isolatedAlarmOwner();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late RecurringScheduleRepositoryImpl recurring;
  late PreparationRepositoryImpl preparations;
  late ScheduleRepositoryImpl schedules;
  late AlarmRepositoryImpl alarms;
  late AlarmRegistryRepositoryImpl registry;
  late _NativeAlarms native;
  var now = DateTime.utc(2030, 1, 1);

  AlarmRegistryRepositoryImpl openRegistry() => AlarmRegistryRepositoryImpl(
    localDataSource: AlarmRegistryLocalDataSourceImpl(),
  );

  ReconcileAlarmsUseCase reconcile() => ReconcileAlarmsUseCase.test(
    alarms,
    registry,
    native,
    _Notifications(),
    nowProvider: () => now,

    operations: isolatedOwner,
  );

  Future<void> createSeries(
    String id,
    DateTime start, {
    String zone = 'UTC',
    int? count,
  }) => recurring.create(
    ScheduleEntity(
      id: id,
      place: PlaceEntity(id: 'place-$id', placeName: 'Office'),
      scheduleName: id,
      scheduleTime: start,
      timeZoneId: zone,
      moveTime: const Duration(minutes: 20),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 5),
      scheduleNote: '',
    ),
    _preparation(25),
    RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      start: start,
      timeZoneId: zone,
      count: count,
    ),
  );

  setUp(() async {
    now = DateTime.utc(2030, 1, 1);
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
    await database.userDao.updateAlarmSettings(
      userId: 'local-profile',
      enabled: true,
    );
    final preparationSource = PreparationLocalDataSourceImpl(
      appDatabase: database,
    );
    // The series must use its own 25-minute preparation, not this default.
    await preparationSource.createDefaultPreparation(
      _preparation(90),
      userId: 'local-profile',
    );
    preparations = PreparationRepositoryImpl(
      preparationLocalDataSource: preparationSource,
      userRepository: _UnusedUser(),
      database: database,
    );
    recurring = RecurringScheduleRepositoryImpl(database, now: () => now);
    schedules = ScheduleRepositoryImpl(
      database: database,
      timedPreparationRepository: _UnusedTimers(),
      recurringScheduleRepository: recurring,
    );
    alarms = AlarmRepositoryImpl(
      database: database,
      scheduleRepository: schedules,
      preparationRepository: preparations,
      recurringScheduleRepository: recurring,
    );
    registry = openRegistry();
    native = _NativeAlarms();
  });

  tearDown(() async {
    await schedules.dispose();
    await preparations.dispose();
    await database.close();
  });

  test(
    'actual create/update entrypoints rerun after snapshot and retain nearest 60 without materialize loop',
    () async {
      await createSeries('morning', DateTime.utc(2030, 1, 2, 9));
      final gate = LocalDataOperationGate();
      final owner = AlarmOperationCoordinator(gate);
      addTearDown(owner.dispose);
      final blocked = _BlockingAlarmWindow(alarms)..block(1);
      final notifications = _Notifications();
      final useCase = ReconcileAlarmsUseCase.test(
        blocked,
        registry,
        native,
        notifications,
        operations: owner,
        nowProvider: () => now,
        timeZoneProvider: () async => 'UTC',
      );
      final effects = ScheduleMutationAlarmEffectsCoordinator(
        CancelScheduleAlarmUseCase(
          registry,
          native,
          notifications,
          operations: owner,
        ),
        useCase,
      );
      final first = useCase();
      await blocked.entered[1]!.future;
      final early = ScheduleEntity(
        id: 'new-nearest',
        place: const PlaceEntity(id: 'new-place', placeName: 'New'),
        scheduleName: 'New',
        scheduleTime: now.add(const Duration(hours: 4)),
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
        moveTime: Duration.zero,
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
      );
      await CreateScheduleWithPlaceUseCase(schedules, effects)(early);
      blocked.release[1]!.complete();
      await first;
      await owner.cleanup(() async {});
      expect(
        (await registry.loadAll()).map((record) => record.scheduleId),
        contains('new-nearest'),
      );
      expect(await registry.loadAll(), hasLength(60));
      await pumpEventQueue();
      expect(blocked.calls, 2);

      blocked.block(3);
      final beforeUpdate = useCase();
      await blocked.entered[3]!.future;
      await UpdateScheduleUseCase(schedules, effects)(
        early.copyWith(scheduleTime: now.add(const Duration(days: 100))),
      );
      blocked.release[3]!.complete();
      await beforeUpdate;
      await owner.cleanup(() async {});
      expect(
        (await registry.loadAll()).map((record) => record.scheduleId),
        isNot(contains('new-nearest')),
      );
      expect(await registry.loadAll(), hasLength(60));
      await pumpEventQueue();
      expect(blocked.calls, 4);
    },
  );

  test(
    'actual default and custom preparation commits request latest delivery timing',
    () async {
      final gate = LocalDataOperationGate();
      final owner = AlarmOperationCoordinator(gate);
      addTearDown(owner.dispose);
      final blocked = _BlockingAlarmWindow(alarms);
      final useCase = ReconcileAlarmsUseCase.test(
        blocked,
        registry,
        native,
        _Notifications(),
        operations: owner,
        nowProvider: () => now,
        timeZoneProvider: () async => 'UTC',
      );
      await schedules.createSchedule(
        ScheduleEntity(
          id: 'prepared',
          place: const PlaceEntity(id: 'p', placeName: 'Place'),
          scheduleName: 'Prepared',
          scheduleTime: now.add(const Duration(hours: 5)),
          timeZoneId: 'UTC',
          occurrenceOffsetSeconds: 0,
          moveTime: Duration.zero,
          isChanged: false,
          isStarted: false,
          scheduleSpareTime: Duration.zero,
          scheduleNote: '',
        ),
      );
      await useCase();
      var previous = (await registry.loadAll()).single.alarmTime;
      final mutations = <(Future<void> Function(), int)>[
        (
          () => UpdateDefaultPreparationUseCase(preparations, useCase)(
            _preparation(30),
          ),
          60,
        ),
        (
          () => CreateCustomPreparationUseCase(preparations, useCase)(
            _preparation(60),
            'prepared',
          ),
          -30,
        ),
        (
          () => UpdatePreparationByScheduleIdUseCase(preparations, useCase)(
            _preparation(10),
            'prepared',
          ),
          50,
        ),
      ];
      for (final (mutate, deltaMinutes) in mutations) {
        final pass = blocked.calls + 1;
        blocked.block(pass);
        final old = useCase();
        await blocked.entered[pass]!.future;
        await mutate();
        blocked.release[pass]!.complete();
        await old;
        // Wait for the use case's accepted pass; do not inject a test request
        // that could hide a missing post-commit integration.
        await owner.cleanup(() async {});
        expect((await registry.loadAll()).map((record) => record.scheduleId), [
          'prepared',
        ]);
        final actual = (await registry.loadAll()).single.alarmTime;
        expect(actual, previous.add(Duration(minutes: deltaMinutes)));
        previous = actual;
      }
    },
  );

  test(
    'two unbounded series share the nearest 60 alarms and survive reopening',
    () async {
      await createSeries('morning', DateTime.utc(2030, 1, 2, 9));
      await createSeries('evening', DateTime.utc(2030, 1, 2, 18));
      expect((await reconcile()()).status, AlarmReconciliationStatus.armed);
      final records = await registry.loadAll();
      expect(records, hasLength(60));
      final expectedTimes = [
        for (var day = 2; day <= 31; day++) ...[
          DateTime.utc(2030, 1, day, 8, 10),
          DateTime.utc(2030, 1, day, 17, 10),
        ],
      ];
      expect(records.map((record) => record.alarmTime.toUtc()), expectedTimes);
      expect(native.scheduled, hasLength(60));
      // Recreate both application objects against persisted registry JSON.
      registry = openRegistry();
      expect((await reconcile()()).status, AlarmReconciliationStatus.armed);
      expect(native.scheduled, hasLength(60));
      expect(native.canceled, isEmpty);
      expect(
        (await registry.loadAll()).map((r) => r.scheduleId),
        records.map((r) => r.scheduleId),
      );
    },
  );

  test(
    'deletion cancels one alarm, refills capacity and stays excluded',
    () async {
      await createSeries('daily', DateTime.utc(2030, 1, 2, 9));
      await reconcile()();
      final before = await registry.loadAll();
      final removedId = before[2].scheduleId;
      final removed = (await database.scheduleDao.getScheduleList())
          .map((row) => row.toScheduleEntity())
          .singleWhere((schedule) => schedule.id == removedId);
      await recurring.delete(removed, RecurringEditScope.occurrence);
      await reconcile()();
      final after = await registry.loadAll();
      expect(after, hasLength(60));
      expect(after.any((r) => r.scheduleId == removedId), isFalse);
      expect(native.canceled.map((r) => r.scheduleId), [removedId]);
      expect(native.scheduled, hasLength(61));
      expect(after.last.alarmTime.toUtc(), DateTime.utc(2030, 3, 3, 8, 10));
      registry = openRegistry();
      await reconcile()();
      expect(native.scheduled, hasLength(61));
      expect(
        (await registry.loadAll()).any((r) => r.scheduleId == removedId),
        isFalse,
      );
    },
  );

  test(
    'a previous civil date in a negative offset still supplies a future alarm',
    () async {
      now = DateTime.utc(2030, 1, 2, 1);
      await createSeries(
        'late-evening',
        DateTime.utc(2030, 1, 1, 19),
        zone: 'America/Los_Angeles',
        count: 1,
      );
      expect((await reconcile()()).status, AlarmReconciliationStatus.armed);
      final record = (await registry.loadAll()).single;
      expect(record.alarmTime.toUtc(), DateTime.utc(2030, 1, 2, 2, 10));
      expect(native.scheduled, hasLength(1));
    },
  );
}

PreparationEntity _preparation(int minutes) => PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'original-step',
      preparationName: 'Get ready',
      preparationTime: Duration(minutes: minutes),
      nextPreparationId: null,
    ),
  ],
);

class _UnusedUser extends Fake implements UserRepository {}

class _UnusedTimers extends Fake implements TimedPreparationRepository {}

class _NativeAlarms extends Fake implements AlarmSchedulerService {
  final pending = <String>{};
  @override
  Future<DeliveryObservation> observePendingNativeAlarms(
    Iterable<String> ids,
  ) async => DeliveryObservation(
    source: DeliveryObservationSource.iosAlarmKit,
    entries: pending
        .map((id) => PendingDelivery(id: id, scheduleId: id))
        .toList(),
  );
  final scheduled = <ScheduledAlarmRecord>[];
  final canceled = <ScheduledAlarmRecord>[];

  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async =>
      const AlarmSchedulerCapabilities(
        supportsNativeAlarm: true,
        nativeAlarmProvider: AlarmProvider.iosAlarmKit,
      );

  @override
  Future<AlarmPermissionState> checkPermission() async =>
      AlarmPermissionState.granted;

  @override
  Future<void> scheduleNativeAlarm(ScheduledAlarmRecord record) async {
    scheduled.add(record);
    pending.add(record.scheduleId);
  }

  @override
  Future<void> cancelNativeAlarm(ScheduledAlarmRecord record) async {
    canceled.add(record);
    pending.remove(record.scheduleId);
  }
}

class _Notifications extends Fake implements FallbackAlarmNotificationService {
  @override
  Future<DeliveryObservation> observePending() async =>
      const DeliveryObservation(
        source: DeliveryObservationSource.iosNotificationCenter,
        entries: [],
      );
  AlarmPermissionState timingPermission = AlarmPermissionState.unsupported;
  int timingRequestCount = 0;

  @override
  Future<AlarmPermissionState> checkExactTimingPermission() async =>
      timingPermission;

  @override
  Future<AlarmPermissionState> requestExactTimingPermission() async {
    timingRequestCount++;
    return timingPermission;
  }

  @override
  Future<AlarmPermissionState> checkPermission() async =>
      AlarmPermissionState.denied;
}

class _BlockingAlarmWindow implements AlarmRepository {
  _BlockingAlarmWindow(this.delegate);
  final AlarmRepository delegate;
  int calls = 0;
  final entered = <int, Completer<void>>{};
  final release = <int, Completer<void>>{};
  void block(int pass) {
    entered[pass] = Completer<void>();
    release[pass] = Completer<void>();
  }

  @override
  Future<AlarmSettings> getAlarmSettings() => delegate.getAlarmSettings();
  @override
  Future<AlarmSettings> updateAlarmSettings({required bool alarmsEnabled}) =>
      delegate.updateAlarmSettings(alarmsEnabled: alarmsEnabled);
  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime start,
    DateTime end,
  ) async {
    final pass = ++calls;
    final result = await delegate.getAlarmWindow(start, end);
    entered[pass]?.complete();
    await release[pass]?.future;
    return result;
  }
}
