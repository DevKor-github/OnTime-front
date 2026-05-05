import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

@Injectable()
class DeleteScheduleUseCase {
  final ScheduleRepository _scheduleRepository;
  final CancelScheduleAlarmUseCase _cancelScheduleAlarmUseCase;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;

  DeleteScheduleUseCase(
    this._scheduleRepository,
    this._cancelScheduleAlarmUseCase,
    this._reconcileAlarmsUseCase,
  );

  Future<void> call(ScheduleEntity schedule) async {
    await _scheduleRepository.deleteSchedule(schedule);
    await _cancelScheduleAlarmUseCase(schedule.id);
    unawaited(_reconcileAlarmsUseCase());
  }
}
