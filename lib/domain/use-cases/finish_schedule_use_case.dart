import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_schedule_alarm_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

@Injectable()
class FinishScheduleUseCase {
  final ScheduleRepository _scheduleRepository;
  final CancelScheduleAlarmUseCase _cancelScheduleAlarmUseCase;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;

  FinishScheduleUseCase(
    this._scheduleRepository,
    this._cancelScheduleAlarmUseCase,
    this._reconcileAlarmsUseCase,
  );

  Future<void> call(String scheduleId, int latenessTime) async {
    await _scheduleRepository.finishSchedule(scheduleId, latenessTime);
    await _cancelScheduleAlarmUseCase(scheduleId);
    unawaited(_reconcileAlarmsUseCase());
  }
}
