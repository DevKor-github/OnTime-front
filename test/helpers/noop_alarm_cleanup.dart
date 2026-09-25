import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';

/// Backup-only fixtures have no platform registrations. Concurrency integration
/// uses the real cleanup use case and a stateful platform fake instead.
class NoopAlarmCleanup implements CancelAllAlarmsUseCase {
  @override
  AlarmOperationCoordinator get operations =>
      throw UnsupportedError('Use actual cleanup for reset protocol tests');
  @override
  Future<T> withCleanupOwner<T>(
    Future<T> Function(AlarmRegistrationCleanup) action,
  ) => throw UnsupportedError('Use actual cleanup for reset protocol tests');
  @override
  Future<void> call() async {}
  @override
  Future<void> forDataReplacement() async {}
}
