import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

@Injectable()
class CancelScheduleAlarmUseCase {
  final AlarmRegistryRepository _registryRepository;
  final AlarmSchedulerService _schedulerService;
  final FallbackAlarmNotificationService _fallbackNotificationService;

  CancelScheduleAlarmUseCase(
    this._registryRepository,
    this._schedulerService,
    this._fallbackNotificationService,
  );

  Future<void> call(String scheduleId) async {
    final records = await _registryRepository.loadAll();
    final matchingRecords = records
        .where((record) => record.scheduleId == scheduleId)
        .toList(growable: false);

    for (final record in matchingRecords) {
      try {
        if (record.provider == AlarmProvider.localNotification) {
          await _fallbackNotificationService.cancelFallbackAlarm(record);
        } else if (record.provider != AlarmProvider.none) {
          await _schedulerService.cancelNativeAlarm(record);
        }
      } catch (_) {
        // Keep cleanup idempotent when the platform has already removed it.
      }
    }

    await _registryRepository.deleteByScheduleId(scheduleId);
  }
}
