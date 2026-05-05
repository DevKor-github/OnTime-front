import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

@Injectable()
class CreateScheduleWithPlaceUseCase {
  final ScheduleRepository _scheduleRepository;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;

  CreateScheduleWithPlaceUseCase(
    this._scheduleRepository,
    this._reconcileAlarmsUseCase,
  );

  Future<void> call(ScheduleEntity schedule) async {
    await _scheduleRepository.createSchedule(schedule);
    unawaited(_reconcileAlarmsUseCase());
  }
}
