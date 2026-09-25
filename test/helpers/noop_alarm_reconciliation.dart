import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

class NoopAlarmReconciliation implements ReconcileAlarmsUseCase {
  int callCount = 0;
  @override
  Future<AlarmReconciliationResult> call() async {
    callCount++;
    final now = DateTime.utc(2026);
    return AlarmReconciliationResult(
      status: AlarmReconciliationStatus.armed,
      nativeAlarmProvider: AlarmProvider.none,
      fallbackProvider: AlarmProvider.none,
      armedScheduleIds: const [],
      skippedScheduleCount: 0,
      failures: const [],
      scheduleWindowStart: now,
      scheduleWindowEnd: now,
      alarmCoverageStart: now,
      alarmCoverageEnd: now,
    );
  }
}
