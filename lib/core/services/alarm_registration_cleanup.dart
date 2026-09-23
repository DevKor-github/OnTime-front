import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

/// Invoked only by the schedule-delivery owner, including replacement cleanup.
/// Provider cancellation already performs its platform-specific read-back.
final class AlarmRegistrationCleanup {
  AlarmRegistrationCleanup(
    this.registry,
    this.scheduler,
    this.fallback,
    this.operations,
  );
  final AlarmRegistryRepository registry;
  final AlarmSchedulerService scheduler;
  final FallbackAlarmNotificationService fallback;
  final AlarmOperationCoordinator operations;

  Future<List<ScheduledAlarmRecord>> cancelRecords(
    List<ScheduledAlarmRecord> records,
  ) async {
    if (records.isNotEmpty) await operations.remember(registry, records);
    final failed = <ScheduledAlarmRecord>[];
    for (final record in records) {
      try {
        if (record.provider == AlarmProvider.localNotification) {
          await fallback.cancelFallbackAlarm(record);
        } else if (record.provider != AlarmProvider.none) {
          await scheduler.cancelNativeAlarm(record);
        }
      } catch (_) {
        failed.add(AlarmOperationCoordinator.ownershipOnly(record));
      }
    }
    return failed;
  }

  Future<void> cancelMatching({String? scheduleId}) async {
    final stored = await operations.loadRecords(registry);
    final targets = stored
        .where(
          (record) => scheduleId == null || record.scheduleId == scheduleId,
        )
        .toList();
    final failed = await cancelRecords(targets);
    await operations.replaceRecords(registry, [
      if (scheduleId != null)
        ...stored.where((record) => record.scheduleId != scheduleId),
      ...failed,
    ]);
    if (failed.isNotEmpty) throw const AlarmCleanupIncomplete();
  }
}
