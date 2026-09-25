import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/detailed_notification_preference_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/presentation/my_page/cubit/detailed_notification_settings_cubit.dart';

void main() {
  late LocalDataOperationGate gate;
  late AlarmOperationCoordinator owner;
  late _Preferences preferences;
  late _Reconcile reconcile;
  late DetailedNotificationSettingsCubit cubit;
  setUp(() {
    gate = LocalDataOperationGate();
    owner = AlarmOperationCoordinator(gate);
    preferences = _Preferences(gate);
    reconcile = _Reconcile();
    cubit = DetailedNotificationSettingsCubit.test(
      preferences,
      reconcile,
      operations: owner,
      delayNotice: const Duration(milliseconds: 20),
    );
  });
  tearDown(() async {
    await cubit.close();
    owner.dispose();
    gate.dispose();
  });

  test('unknown loading and read failure never become a saved false', () async {
    preferences.readBarrier = Completer<void>();
    final refresh = cubit.refresh();
    expect(cubit.state.displayedEnabled, isNull);
    expect(cubit.state.canRequest, isFalse);
    cubit.request(true);
    expect(preferences.writes, isEmpty);
    preferences.failRead = true;
    preferences.readBarrier!.complete();
    await refresh;
    expect(cubit.state.load, DetailedPreferenceLoad.failed);
    expect(cubit.state.confirmedEnabled, isNull);
    preferences.failRead = false;
    preferences.readBarrier = null;
    preferences.value = true;
    await cubit.retry();
    expect(cubit.state.confirmedEnabled, isTrue);
  });

  test('late resume read cannot overwrite a newer requested OFF', () async {
    preferences.value = true;
    await cubit.refresh();
    preferences.readBarrier = Completer<void>();
    final refresh = cubit.refresh();
    cubit.request(false);
    preferences.readBarrier!.complete();
    await refresh;
    await pumpEventQueue();
    expect(cubit.state.confirmedEnabled, isFalse);
    expect(preferences.value, isFalse);
  });

  test(
    'latest intent drains writes serially and skips obsolete ON delivery',
    () async {
      await cubit.refresh();
      final baseline = reconcile.calls;
      preferences.writeBarrier = Completer<void>();
      cubit.request(true);
      cubit.request(false);
      expect(cubit.state.requestedEnabled, isFalse);
      expect(owner.allowsDetailed(owner.captureContentPermit()), isFalse);
      preferences.writeBarrier!.complete();
      await pumpEventQueue();
      expect(preferences.writes, [true, false]);
      expect(preferences.maxConcurrentWrites, 1);
      expect(reconcile.calls, baseline + 1);
      expect(cubit.state.confirmedEnabled, isFalse);
      expect(cubit.state.requestedEnabled, isNull);
    },
  );

  test(
    'burst keeps only last waiting value and duplicate choice has no extra write',
    () async {
      await cubit.refresh();
      preferences.writeBarrier = Completer<void>();
      cubit.request(true);
      cubit.request(false);
      cubit.request(true);
      cubit.request(true);
      preferences.writeBarrier!.complete();
      await pumpEventQueue();
      expect(preferences.writes, [true, true]);
      expect(cubit.state.confirmedEnabled, isTrue);
      final before = preferences.writes.length;
      cubit.request(true);
      await pumpEventQueue();
      expect(preferences.writes.length, before);
    },
  );

  test(
    'failed OFF keeps confirmed ON and its hold until explicit ON',
    () async {
      preferences.value = true;
      await cubit.refresh();
      preferences.failWrite = true;
      cubit.request(false);
      await pumpEventQueue();
      expect(cubit.state.confirmedEnabled, isTrue);
      expect(cubit.state.requestedEnabled, isFalse);
      expect(cubit.state.save, DetailedPreferenceSave.failed);
      expect(owner.allowsDetailed(owner.captureContentPermit()), isFalse);
      final writes = preferences.writes.length;
      await pumpEventQueue();
      expect(preferences.writes.length, writes);
      preferences.failWrite = false;
      cubit.request(true);
      await pumpEventQueue();
      expect(owner.allowsDetailed(owner.captureContentPermit()), isTrue);
    },
  );

  test(
    'committed write response failure uses readback and does not duplicate write',
    () async {
      await cubit.refresh();
      preferences.failAfterCommit = true;
      cubit.request(true);
      await pumpEventQueue();
      expect(cubit.state.confirmedEnabled, isTrue);
      expect(cubit.state.save, DetailedPreferenceSave.idle);
      expect(preferences.writes, [true]);
    },
  );

  test(
    'write and readback failure remain unknown, explicit retry recovers',
    () async {
      preferences.value = true;
      await cubit.refresh();
      preferences.failWrite = true;
      preferences.failRead = true;
      cubit.request(false);
      await pumpEventQueue();
      expect(cubit.state.confirmedEnabled, isNull);
      expect(cubit.state.save, DetailedPreferenceSave.failed);
      expect(cubit.state.canRequest, isFalse);
      preferences.failWrite = false;
      preferences.failRead = false;
      await cubit.retry();
      await pumpEventQueue();
      expect(cubit.state.confirmedEnabled, isFalse);
    },
  );

  test(
    'an unreturned platform Future does not block the next OFF DB commit',
    () async {
      await cubit.refresh();
      reconcile.block = Completer<AlarmReconciliationResult>();
      cubit.request(true);
      await pumpEventQueue();
      cubit.request(false);
      await pumpEventQueue();
      expect(preferences.value, isFalse);
      expect(cubit.state.confirmedEnabled, isFalse);
      final calls = reconcile.calls;
      await cubit.retry();
      expect(reconcile.calls, calls);
      reconcile.block!.complete(_result());
      await pumpEventQueue();
      expect(cubit.state.confirmedEnabled, isFalse);
    },
  );

  test(
    'failed OFF persistence retries while an older OS Future is unreturned',
    () async {
      await cubit.refresh();
      reconcile.block = Completer<AlarmReconciliationResult>();
      cubit.request(true);
      await pumpEventQueue();
      preferences.failWrite = true;
      cubit.request(false);
      await pumpEventQueue();
      expect(cubit.state.save, DetailedPreferenceSave.failed);
      preferences.failWrite = false;
      await cubit.retry();
      expect(preferences.value, isFalse);
      expect(cubit.state.confirmedEnabled, isFalse);
      reconcile.block!.complete(_result());
      await pumpEventQueue();
    },
  );

  test('failed ON does not claim an unresolved OFF hold', () async {
    await cubit.refresh();
    preferences.failWrite = true;
    cubit.request(true);
    await pumpEventQueue();
    expect(cubit.state.confirmedEnabled, isFalse);
    expect(cubit.state.requestedEnabled, isTrue);
    expect(cubit.state.delivery, DetailedPreferenceDelivery.needsCheck);
    expect(cubit.state.save, DetailedPreferenceSave.failed);
    preferences.failWrite = false;
    await cubit.retry();
    await pumpEventQueue();
    expect(cubit.state.confirmedEnabled, isTrue);
  });

  test(
    'route unsubscribe does not discard pending OFF; new subscriber sees it',
    () async {
      preferences.value = true;
      await cubit.refresh();
      final subscription = cubit.stream.listen((_) {});
      preferences.writeBarrier = Completer<void>();
      cubit.request(false);
      await subscription.cancel();
      expect(cubit.state.requestedEnabled, isFalse);
      preferences.writeBarrier!.complete();
      await pumpEventQueue();
      expect(cubit.state.confirmedEnabled, isFalse);
      expect(preferences.value, isFalse);
    },
  );

  test(
    'generation change drops waiting intent and never writes the new store',
    () async {
      await cubit.refresh();
      preferences.writeBarrier = Completer<void>();
      cubit.request(true);
      cubit.request(false);
      await gate.run(() async {}, replacesData: true);
      preferences.writeBarrier!.complete();
      await pumpEventQueue();
      expect(preferences.value, isFalse);
      expect(preferences.writes, [true]);
      expect(cubit.state.requestedEnabled, isNull);
      expect(cubit.state.load, DetailedPreferenceLoad.unavailable);
      await cubit.refresh();
      expect(cubit.state.load, DetailedPreferenceLoad.ready);
    },
  );

  for (final entry in {
    AlarmFailureReason.cancellationFailed:
        DetailedPreferenceDelivery.cancellationUnconfirmed,
    AlarmFailureReason.observationFailed: DetailedPreferenceDelivery.needsCheck,
    AlarmFailureReason.platformError:
        DetailedPreferenceDelivery.schedulingFailed,
    AlarmFailureReason.contentDeferred:
        DetailedPreferenceDelivery.contentDeferred,
  }.entries) {
    test('delivery ${entry.key} preserves the saved preference', () async {
      preferences.value = true;
      await cubit.refresh();
      reconcile.result = _result(reason: entry.key);
      cubit.request(false);
      await pumpEventQueue();
      expect(cubit.state.confirmedEnabled, isFalse);
      expect(cubit.state.delivery, entry.value);
      final writes = preferences.writes.length;
      reconcile.result = _result();
      await cubit.retry();
      expect(preferences.writes.length, writes);
      expect(cubit.state.delivery, DetailedPreferenceDelivery.noUpcoming);
    });
  }
}

AlarmReconciliationResult _result({AlarmFailureReason? reason}) {
  final now = DateTime.utc(2030);
  return AlarmReconciliationResult(
    status: reason == null
        ? AlarmReconciliationStatus.armed
        : AlarmReconciliationStatus.partial,
    nativeAlarmProvider: AlarmProvider.none,
    fallbackProvider: AlarmProvider.localNotification,
    armedScheduleIds: const [],
    skippedScheduleCount: 0,
    failures: [if (reason != null) AlarmFailure(reason: reason)],
    scheduleWindowStart: now,
    scheduleWindowEnd: now,
    alarmCoverageStart: now,
    alarmCoverageEnd: now,
  );
}

class _Reconcile implements ReconcileAlarmsUseCase {
  int calls = 0;
  AlarmReconciliationResult result = _result();
  Completer<AlarmReconciliationResult>? block;
  @override
  Future<AlarmReconciliationResult> call() async {
    calls++;
    return block == null ? result : await block!.future;
  }
}

class _Preferences implements DetailedNotificationPreferencePort {
  _Preferences(this.gate);
  final LocalDataOperationGate gate;
  bool value = false;
  bool failRead = false, failWrite = false, failAfterCommit = false;
  Completer<void>? readBarrier, writeBarrier;
  final writes = <bool>[];
  int concurrentWrites = 0, maxConcurrentWrites = 0;
  DetailedNotificationPreferenceSnapshot snapshot(
    int generation,
    bool enabled,
  ) => DetailedNotificationPreferenceSnapshot(
    generation: generation,
    detailedEnabled: enabled,
    scheduleNotificationsEnabled: true,
  );
  @override
  Future<DetailedNotificationPreferenceSnapshot> read({
    required int expectedGeneration,
  }) async {
    final old = value;
    await readBarrier?.future;
    gate.checkWrite(expectedGeneration);
    if (failRead) throw StateError('synthetic read failure');
    return snapshot(expectedGeneration, old);
  }

  @override
  Future<DetailedNotificationPreferenceSnapshot> write(
    bool enabled, {
    required int expectedGeneration,
  }) async {
    writes.add(enabled);
    concurrentWrites++;
    if (concurrentWrites > maxConcurrentWrites) {
      maxConcurrentWrites = concurrentWrites;
    }
    try {
      await writeBarrier?.future;
      gate.checkWrite(expectedGeneration);
      if (failWrite) throw StateError('synthetic write failure');
      value = enabled;
      if (failAfterCommit) throw StateError('synthetic response failure');
      return snapshot(expectedGeneration, value);
    } finally {
      concurrentWrites--;
    }
  }
}
