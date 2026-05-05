import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

@Injectable()
class UpdateScheduleUseCase {
  final ScheduleRepository _scheduleRepository;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;

  UpdateScheduleUseCase(
    this._scheduleRepository,
    this._reconcileAlarmsUseCase,
  );

  Future<void> call(ScheduleEntity schedule) async {
    await _scheduleRepository.updateSchedule(schedule);
    unawaited(_reconcileAlarmsUseCase());
  }
}
