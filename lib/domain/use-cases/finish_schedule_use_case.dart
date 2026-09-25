import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

@Injectable()
class FinishScheduleUseCase {
  final ScheduleRepository _scheduleRepository;
  final AlarmOperationCoordinator _operations;
  final ScheduleMutationAlarmEffectsCoordinator _alarmEffectsCoordinator;

  FinishScheduleUseCase(
    this._scheduleRepository,
    this._alarmEffectsCoordinator, {
    @ignoreParam AlarmOperationCoordinator? operations,
  }) : _operations = operations ?? AlarmOperationCoordinator.shared;

  Future<void> call(String scheduleId, int latenessTime) async {
    final owner = _operations;
    final lease = owner.capture();
    await owner.run(lease, () async {
      try {
        await _scheduleRepository.startSchedule(scheduleId);
      } on ScheduleStartRejected {
        // Repeated finish remains idempotent; start itself rejects ended runs.
      }
      await _scheduleRepository.finishSchedule(scheduleId, latenessTime);
    });
    lease.check();
    await _alarmEffectsCoordinator(
      operation: ScheduleMutationAlarmOperation.finished,
      scheduleId: scheduleId,
    );
  }
}
