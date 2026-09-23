import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';

/// Backup-only fixtures have no platform registrations. Concurrency integration
/// uses the real cleanup use case and a stateful platform fake instead.
class NoopAlarmCleanup implements CancelAllAlarmsUseCase {
  @override
  Future<void> call() async {}
  @override
  Future<void> forDataReplacement() async {}
}
