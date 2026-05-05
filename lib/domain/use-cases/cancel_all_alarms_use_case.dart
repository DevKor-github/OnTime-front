import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';

@Injectable()
class CancelAllAlarmsUseCase {
  final AlarmRepository _alarmRepository;
  final AlarmRegistryRepository _registryRepository;
  final AlarmSchedulerService _schedulerService;
  final FallbackAlarmNotificationService _fallbackNotificationService;

  CancelAllAlarmsUseCase(
    this._alarmRepository,
    this._registryRepository,
    this._schedulerService,
    this._fallbackNotificationService,
  );

  Future<void> call({bool unregisterDevice = false}) async {
    final records = await _registryRepository.loadAll();
    await cancelRecords(records);
    await _registryRepository.deleteAll();

    if (unregisterDevice) {
      try {
        await _alarmRepository.unregisterCurrentDevice(
          await _alarmRepository.getDeviceId(),
        );
      } catch (_) {
        // Logout/session cleanup must still complete when the backend is gone.
      }
    }
  }

  Future<void> cancelRecords(List<ScheduledAlarmRecord> records) async {
    for (final record in records) {
      await _cancelRecord(record);
    }
  }

  Future<void> _cancelRecord(ScheduledAlarmRecord record) async {
    try {
      if (record.provider == AlarmProvider.localNotification) {
        await _fallbackNotificationService.cancelFallbackAlarm(record);
      } else if (record.provider != AlarmProvider.none) {
        await _schedulerService.cancelNativeAlarm(record);
      }
    } catch (_) {
      // Best-effort cancellation: stale registry cleanup should not be blocked
      // by a platform channel or notification plugin failure.
    }
  }
}
