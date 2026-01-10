import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_week_use_case.dart';

@Injectable()
class GetNearestUpcomingScheduleUseCase {
  final GetSchedulesByDateUseCase _getScheduleByDateUseCase;
  final LoadPreparationByScheduleIdUseCase _loadPreparationByScheduleIdUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final LoadSchedulesForWeekUseCase _loadSchedulesForWeekUseCase;
  final TimedPreparationRepository _timedPreparationRepository;

  GetNearestUpcomingScheduleUseCase(
      this._getScheduleByDateUseCase,
      this._loadPreparationByScheduleIdUseCase,
      this._getPreparationByScheduleIdUseCase,
      this._loadSchedulesForWeekUseCase,
      this._timedPreparationRepository);

  Stream<ScheduleWithPreparationEntity?> call() async* {
    final DateTime now = DateTime.now();

    _loadSchedulesForWeekUseCase(now);

    final upcomingScheduleStream =
        _getScheduleByDateUseCase(now, now.add(const Duration(days: 2)));
    await for (final upcomingSchedule in upcomingScheduleStream) {
      if (upcomingSchedule.isNotEmpty) {
        try {
          final schedule = upcomingSchedule.firstWhere(
              (s) => s.doneStatus == ScheduleDoneStatus.notEnded,
              orElse: () => throw Exception('No upcoming schedule found'));

          // First try to load locally stored timed preparation
          final localTimed = await _timedPreparationRepository
              .getTimedPreparation(schedule.id);
          if (localTimed != null) {
            yield ScheduleWithPreparationEntity
                .fromScheduleAndPreparationEntity(schedule, localTimed);
            continue;
          }

          // Fallback to fetching canonical preparation from source
          await _loadPreparationByScheduleIdUseCase(schedule.id);
          final preparation =
              await _getPreparationByScheduleIdUseCase(schedule.id);
          final scheduleWithPreparation =
              ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
                  schedule,
                  PreparationWithTimeEntity.fromPreparation(preparation));
          yield scheduleWithPreparation;
        } catch (e) {
          yield null;
          continue;
        }
      } else {
        yield null;
      }
    }
  }
}
