import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_week_use_case.dart';

@Injectable()
class GetNearestUpcomingScheduleUseCase {
  final GetSchedulesByDateUseCase _getScheduleByDateUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final LoadSchedulesForWeekUseCase _loadSchedulesForWeekUseCase;

  GetNearestUpcomingScheduleUseCase(
      this._getScheduleByDateUseCase,
      this._getPreparationByScheduleIdUseCase,
      this._loadSchedulesForWeekUseCase);

  Stream<ScheduleWithPreparationEntity?> call() async* {
    final DateTime now = DateTime.now();

    _loadSchedulesForWeekUseCase(now);

    final upcomingScheduleStream =
        _getScheduleByDateUseCase(now, now.add(const Duration(days: 2)));
    await for (final upcomingSchedule in upcomingScheduleStream) {
      if (upcomingSchedule.isNotEmpty) {
        final preparation =
            await _getPreparationByScheduleIdUseCase(upcomingSchedule.first.id);
        final scheduleWithPreparation =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
                upcomingSchedule.first, preparation);
        yield scheduleWithPreparation;
      } else {
        yield null;
      }
    }
  }
}
