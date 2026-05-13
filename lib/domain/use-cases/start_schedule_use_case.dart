import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/started_schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

@Injectable()
class StartScheduleUseCase {
  StartScheduleUseCase(this._scheduleRepository, this._reconcileAlarmsUseCase);

  final ScheduleRepository _scheduleRepository;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;

  Future<StartedScheduleEntity> call(String scheduleId) async {
    final startedSchedule = await _scheduleRepository.startSchedule(scheduleId);
    unawaited(_reconcileAlarmsUseCase());
    return startedSchedule;
  }
}
