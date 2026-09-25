import '../../helpers/isolated_alarm_owner.dart';
import 'dart:async';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

import 'reconcile_alarms_use_case_test.dart' as fixtures;

class BlockingAlarmRepository extends fixtures.FakeAlarmRepository {
  final snapshots = <int, Completer<void>>{};
  final releases = <int, Completer<void>>{};
  final failedPasses = <int>{};

  void block(int pass) {
    snapshots[pass] = Completer<void>();
    releases[pass] = Completer<void>();
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = List<ScheduleWithPreparationEntity>.of(
      await super.getAlarmWindow(startDate, endDate),
    );
    final pass = alarmWindowRequestCount;
    snapshots[pass]?.complete();
    await releases[pass]?.future;
    if (failedPasses.contains(pass)) throw StateError('read failed');
    return snapshot;
  }
}

void main() {
  late AlarmOperationCoordinator isolatedOwner;
  setUp(() {
    isolatedOwner = isolatedAlarmOwner();
  });
  test(
    'each cutoff finishes without waiting for later edits to become quiet',
    () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.repository
        ..block(1)
        ..block(2)
        ..block(3);
      final first = r.reconcile();
      await r.repository.snapshots[1]!.future;
      r.repository.schedules = [r.schedule('second')];
      final second = r.reconcile();
      r.repository.releases[1]!.complete();
      expect((await first).armedScheduleIds, isEmpty);
      await r.repository.snapshots[2]!.future;
      r.repository.schedules = [r.schedule('third')];
      var thirdDone = false;
      final third = r.reconcile().then((result) {
        thirdDone = true;
        return result;
      });
      r.repository.releases[2]!.complete();
      expect((await second).armedScheduleIds, ['second']);
      await r.repository.snapshots[3]!.future;
      expect(thirdDone, false);
      r.repository.releases[3]!.complete();
      expect((await third).armedScheduleIds, ['third']);
      expect(r.registry.records.map((r) => r.scheduleId), ['third']);
    },
  );

  test(
    'failed snapshot completes its cutoff and still serves a newer request',
    () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.repository
        ..block(1)
        ..failedPasses.add(1);
      final first = r.reconcile();
      await r.repository.snapshots[1]!.future;
      r.repository.schedules = [r.schedule('new')];
      final second = r.reconcile();
      r.repository.releases[1]!.complete();
      expect((await first).status, AlarmReconciliationStatus.partial);
      expect((await second).armedScheduleIds, ['new']);
      expect(r.repository.alarmWindowRequestCount, 2);
    },
  );

  test(
    'failure alone stops; a request from completion starts another pass',
    () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.repository.failedPasses.add(1);
      expect((await r.reconcile()).status, AlarmReconciliationStatus.partial);
      await pumpEventQueue();
      expect(r.repository.alarmWindowRequestCount, 1);
      r.repository.schedules = [r.schedule('later')];
      final result = await r.reconcile().then((_) => r.reconcile());
      expect(result.armedScheduleIds, ['later']);
      expect(r.repository.alarmWindowRequestCount, 3);
    },
  );

  test(
    'replacement waits for the actual late native Future before same-ID reuse',
    () async {
      final native = BlockingNative();
      final r = Rig(native: native);
      addTearDown(r.dispose);
      r.repository.schedules = [r.schedule('same')];
      final first = r.reconcile();
      final invalidated = expectLater(
        first,
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      await native.entered.future;
      var replaced = false;
      final replacement = r.gate.run(() async {
        await r.cancelAll.forDataReplacement();
        replaced = true;
        r.repository.schedules = [r.schedule('same', hours: 3)];
      }, replacesData: true);
      await invalidated;
      await pumpEventQueue();
      expect(replaced, false);
      expect(native.canceledNative, isEmpty);
      await expectLater(
        r.reconcile(),
        throwsA(isA<AlarmOperationInvalidated>()),
      );
      // No timeout, UI completion, or invalidated result releases the OS owner.
      expect(r.registry.records.single.cancellationPending, true);
      native.release.complete();
      await replacement;
      expect(native.events, ['schedule:same', 'cancel:same']);
      expect(native.pendingNative, isEmpty);
      final newResult = await r.reconcile();
      expect(newResult.armedScheduleIds, ['same']);
      expect(native.events, ['schedule:same', 'cancel:same', 'schedule:same']);
      expect(
        r.registry.records.single.alarmTime,
        r.now.add(const Duration(hours: 3)),
      );
    },
  );

  test(
    'caller timeout cannot release ownership of an unreturned native Future',
    () async {
      final native = BlockingNative();
      final r = Rig(native: native);
      addTearDown(r.dispose);
      r.repository.schedules = [r.schedule('timeout')];
      final first = r.reconcile();
      await native.entered.future;
      await expectLater(
        first.timeout(Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      var replaced = false;
      final replacement = r.gate.run(() async {
        await r.cancelAll.forDataReplacement();
        replaced = true;
      }, replacesData: true);
      await pumpEventQueue();
      expect(replaced, false);
      expect(native.events, isEmpty);
      native.release.complete();
      await replacement;
      expect(native.events, ['schedule:timeout', 'cancel:timeout']);
    },
  );

  test('ordinary export busy does not invalidate a requested pass', () async {
    final r = Rig();
    addTearDown(r.dispose);
    final picker = Completer<void>();
    final export = r.gate.run(() => picker.future);
    r.repository.schedules = [r.schedule('during-export')];
    expect((await r.reconcile()).armedScheduleIds, ['during-export']);
    expect(r.gate.generation, 0);
    picker.complete();
    await export;
  });

  test(
    'replacement cancellation failure retains evidence and prevents replacement',
    () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.repository.schedules = [r.schedule('old')];
      await r.reconcile();
      r.fallback.throwOnCancelIds.add('old');
      var replaced = false;
      await expectLater(
        r.gate.run(() async {
          await r.cancelAll.forDataReplacement();
          replaced = true;
        }, replacesData: true),
        throwsA(isA<AlarmCleanupIncomplete>()),
      );
      expect(replaced, false);
      expect(r.registry.records.single.cancellationPending, true);
      expect(
        r.gate.isAvailable,
        true,
      ); // Restore failure preserves usable data.
      r.fallback.throwOnCancelIds.clear();
      expect((await r.reconcile()).armedScheduleIds, ['old']);
    },
  );

  test(
    'delete mutation accepted during snapshot cannot be resurrected by replaceAll',
    () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.repository.schedules = [r.schedule('deleted')];
      await r.reconcile();
      r.repository.block(2);
      final old = r.reconcile();
      await r.repository.snapshots[2]!.future;
      r.repository.schedules = []; // Durable deletion has committed.
      final mutation =
          ScheduleMutationAlarmEffectsCoordinator(r.cancelOne, r.reconcile)(
            operation: ScheduleMutationAlarmOperation.deleted,
            scheduleId: 'deleted',
          );
      r.repository.releases[2]!.complete();
      await old;
      await mutation;
      await r.operations.cleanup(() async {});
      expect(r.repository.alarmWindowRequestCount, 3);
      expect(r.registry.records, isEmpty);
      expect(r.fallback.pendingFallback, isEmpty);
    },
  );

  test(
    'registry write failure is not armed and a queued newer request recovers ownership',
    () async {
      final registry = FailingRegistry();
      final r = Rig(registry: registry);
      addTearDown(r.dispose);
      r.repository
        ..schedules = [r.schedule('latest')]
        ..block(1);
      final first = r.reconcile();
      final failure = expectLater(first, throwsStateError);
      await r.repository.snapshots[1]!.future;
      r.repository.schedules = [r.schedule('latest', hours: 2)];
      final latest = r.reconcile();
      r.repository.releases[1]!.complete();
      await failure;
      expect((await latest).armedScheduleIds, ['latest']);
      expect(registry.failedWrites, 1);
      expect(
        registry.records.single.alarmTime,
        r.now.add(const Duration(hours: 2)),
      );
      expect(r.fallback.canceledFallback.map((r) => r.scheduleId), ['latest']);
    },
  );

  test(
    'detailed OFF accepted after snapshot replaces old content in trailing pass',
    () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.repository
        ..settings = const AlarmSettings(
          alarmsEnabled: true,
          detailedNotificationContent: true,
        )
        ..schedules = [r.schedule('private')]
        ..block(1);
      final first = r.reconcile();
      await r.repository.snapshots[1]!.future;
      r.repository.settings = const AlarmSettings(
        alarmsEnabled: true,
        detailedNotificationContent: false,
      );
      final latest = r.reconcile();
      r.repository.releases[1]!.complete();
      await first;
      expect((await latest).armedScheduleIds, ['private']);
      expect(r.registry.records.single.deliveryContent.detailed, false);
      expect(
        r.registry.records.single.deliveryContent.title,
        isNot(contains('private')),
      );
      expect(r.fallback.canceledFallback.map((r) => r.scheduleId), ['private']);
    },
  );

  test(
    'request after schedule snapshot receives its own latest pass',
    () async {
      final now = DateTime.utc(2026, 9, 24);
      final repository = BlockingAlarmRepository()..block(1);
      final registry = fixtures.FakeAlarmRegistryRepository();
      final scheduler = fixtures.FakeAlarmSchedulerService();
      final fallback = fixtures.FakeFallbackAlarmNotificationService()
        ..permission = AlarmPermissionState.granted;
      final reconcile = ReconcileAlarmsUseCase.test(
        repository,
        registry,
        scheduler,
        fallback,
        nowProvider: () => now,
        timeZoneProvider: () async => 'UTC',

        operations: isolatedOwner,
      );
      final first = reconcile();
      await repository.snapshots[1]!.future;
      repository.schedules = [
        fixtures.scheduleWithAlarmAt(
          id: 'committed-after-snapshot',
          alarmTime: now.add(const Duration(hours: 1)),
        ),
      ];
      final second = reconcile();
      repository.releases[1]!.complete();
      await first;
      final result = await second;

      expect(result.armedScheduleIds, ['committed-after-snapshot']);
      expect(registry.records.map((record) => record.scheduleId), [
        'committed-after-snapshot',
      ]);
      expect(result.status, AlarmReconciliationStatus.armed);
    },
  );
}

class BlockingNative extends fixtures.FakeAlarmSchedulerService {
  BlockingNative() {
    capabilities = const AlarmSchedulerCapabilities(
      supportsNativeAlarm: true,
      nativeAlarmProvider: AlarmProvider.iosAlarmKit,
      fallbackProvider: AlarmProvider.localNotification,
    );
  }
  final entered = Completer<void>();
  final release = Completer<void>();
  final events = <String>[];
  @override
  Future<void> scheduleNativeAlarm(ScheduledAlarmRecord record) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    await super.scheduleNativeAlarm(record);
    events.add('schedule:${record.scheduleId}');
  }

  @override
  Future<void> cancelNativeAlarm(ScheduledAlarmRecord record) async {
    await super.cancelNativeAlarm(record);
    events.add('cancel:${record.scheduleId}');
  }
}

class Rig {
  Rig({
    fixtures.FakeAlarmSchedulerService? native,
    fixtures.FakeAlarmRegistryRepository? registry,
  }) {
    this.registry = registry ?? fixtures.FakeAlarmRegistryRepository();
    scheduler = native ?? fixtures.FakeAlarmSchedulerService();
    operations = AlarmOperationCoordinator(gate);
    reconcile = ReconcileAlarmsUseCase.test(
      repository,
      this.registry,
      scheduler,
      fallback,
      operations: operations,
      nowProvider: () => now,
      timeZoneProvider: () async => 'UTC',
    );
    cancelAll = CancelAllAlarmsUseCase(
      this.registry,
      scheduler,
      fallback,
      operations: operations,
    );
    cancelOne = CancelScheduleAlarmUseCase(
      this.registry,
      scheduler,
      fallback,
      operations: operations,
    );
  }
  final now = DateTime.utc(2026, 9, 24);
  final gate = LocalDataOperationGate();
  final repository = BlockingAlarmRepository();
  late final fixtures.FakeAlarmRegistryRepository registry;
  final fallback = fixtures.FakeFallbackAlarmNotificationService()
    ..permission = AlarmPermissionState.granted;
  late final fixtures.FakeAlarmSchedulerService scheduler;
  late final AlarmOperationCoordinator operations;
  late final ReconcileAlarmsUseCase reconcile;
  late final CancelAllAlarmsUseCase cancelAll;
  late final CancelScheduleAlarmUseCase cancelOne;
  ScheduleWithPreparationEntity schedule(String id, {int hours = 1}) =>
      fixtures.scheduleWithAlarmAt(
        id: id,
        alarmTime: now.add(Duration(hours: hours)),
      );
  void dispose() {
    operations.dispose();
    gate.dispose();
  }
}

class FailingRegistry extends fixtures.FakeAlarmRegistryRepository {
  int failedWrites = 0;
  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) async {
    if (failedWrites == 0 &&
        records.any((record) => !record.cancellationPending)) {
      failedWrites++;
      throw StateError('synthetic registry write failure');
    }
    await super.replaceAll(records);
  }
}
