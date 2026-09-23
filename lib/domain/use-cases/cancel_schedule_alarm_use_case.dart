import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

@Injectable()
class CancelScheduleAlarmUseCase {
  CancelScheduleAlarmUseCase(
    AlarmRegistryRepository registry,
    AlarmSchedulerService scheduler,
    FallbackAlarmNotificationService fallback, {
    @ignoreParam AlarmOperationCoordinator? operations,
  }) : _operations = operations ?? AlarmOperationCoordinator.shared,
       _cleanup = AlarmRegistrationCleanup(
         registry,
         scheduler,
         fallback,
         operations ?? AlarmOperationCoordinator.shared,
       );

  final AlarmOperationCoordinator _operations;
  final AlarmRegistrationCleanup _cleanup;

  Future<void> call(String scheduleId) async {
    final lease = _operations.capture();
    await _operations.run(
      lease,
      () => _cleanup.cancelMatching(scheduleId: scheduleId),
    );
    lease.check();
  }
}
