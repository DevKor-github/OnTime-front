import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

void main() {
  test(
    'created and updated schedules reconcile without targeted cancellation',
    () async {
      final cancel = _FakeCancelScheduleAlarmUseCase();
      final reconcile = _FakeReconcileAlarmsUseCase();
      final coordinator = ScheduleMutationAlarmEffectsCoordinator(
        cancel,
        reconcile,
      );

      await coordinator(
        operation: ScheduleMutationAlarmOperation.created,
        scheduleId: 'schedule-1',
      );
      await coordinator(
        operation: ScheduleMutationAlarmOperation.updated,
        scheduleId: 'schedule-1',
      );
      await pumpEventQueue();

      expect(cancel.cancelledScheduleIds, isEmpty);
      expect(reconcile.callCount, 2);
    },
  );

  test(
    'deleted and finished schedules cancel targeted alarm before reconciling',
    () async {
      final events = <String>[];
      final cancel = _FakeCancelScheduleAlarmUseCase(events: events);
      final reconcile = _FakeReconcileAlarmsUseCase(events: events);
      final coordinator = ScheduleMutationAlarmEffectsCoordinator(
        cancel,
        reconcile,
      );

      await coordinator(
        operation: ScheduleMutationAlarmOperation.deleted,
        scheduleId: 'schedule-1',
      );
      await coordinator(
        operation: ScheduleMutationAlarmOperation.finished,
        scheduleId: 'schedule-2',
      );
      await pumpEventQueue();

      expect(events, [
        'cancel:schedule-1',
        'reconcile',
        'cancel:schedule-2',
        'reconcile',
      ]);
    },
  );

  test('reconciliation failures remain best-effort', () async {
    final cancel = _FakeCancelScheduleAlarmUseCase();
    final reconcile = _FakeReconcileAlarmsUseCase()..throwOnCall = true;
    final coordinator = ScheduleMutationAlarmEffectsCoordinator(
      cancel,
      reconcile,
    );

    await coordinator(
      operation: ScheduleMutationAlarmOperation.created,
      scheduleId: 'schedule-1',
    );
    await pumpEventQueue();

    expect(reconcile.callCount, 1);
  });
}

class _FakeCancelScheduleAlarmUseCase implements CancelScheduleAlarmUseCase {
  _FakeCancelScheduleAlarmUseCase({List<String>? events}) : _events = events;

  final cancelledScheduleIds = <String>[];
  final List<String>? _events;

  @override
  Future<void> call(String scheduleId) async {
    cancelledScheduleIds.add(scheduleId);
    _events?.add('cancel:$scheduleId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReconcileAlarmsUseCase implements ReconcileAlarmsUseCase {
  _FakeReconcileAlarmsUseCase({List<String>? events}) : _events = events;

  int callCount = 0;
  bool throwOnCall = false;
  final List<String>? _events;

  @override
  Future<AlarmReconciliationResult> call() async {
    callCount += 1;
    _events?.add('reconcile');
    if (throwOnCall) {
      throw Exception('reconcile failed');
    }
    return AlarmReconciliationResult(
      status: AlarmReconciliationStatus.armed,
      nativeAlarmProvider: AlarmProvider.none,
      fallbackProvider: AlarmProvider.localNotification,
      armedScheduleIds: const [],
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: DateTime.utc(2026, 5, 15),
      scheduleWindowEnd: DateTime.utc(2026, 5, 23),
      alarmCoverageStart: DateTime.utc(2026, 5, 15),
      alarmCoverageEnd: DateTime.utc(2026, 5, 22),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
