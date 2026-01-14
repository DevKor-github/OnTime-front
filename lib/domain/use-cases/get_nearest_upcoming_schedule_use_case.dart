import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
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

  Stream<Result<ScheduleWithPreparationEntity?, Failure>> call() async* {
    final DateTime now = DateTime.now();

    // Trigger load; if it fails, surface error once and continue listening.
    final loadWeekResult = await _loadSchedulesForWeekUseCase(now);
    if (loadWeekResult.isFailure) {
      yield Err(loadWeekResult.failureOrNull!);
    }

    final upcomingScheduleStream =
        _getScheduleByDateUseCase(now, now.add(const Duration(days: 2)));
    await for (final scheduleResult in upcomingScheduleStream) {
      if (scheduleResult.isFailure) {
        yield Err(scheduleResult.failureOrNull!);
        continue;
      }

      final upcomingSchedule = scheduleResult.successOrNull ?? const <ScheduleEntity>[];
      if (upcomingSchedule.isNotEmpty) {
        try {
          final schedule = upcomingSchedule.firstWhere(
              (s) => s.doneStatus == ScheduleDoneStatus.notEnded,
              orElse: () => throw Exception('No upcoming schedule found'));

          // First try to load locally stored timed preparation
          final localTimedResult =
              await _timedPreparationRepository.getTimedPreparation(schedule.id);
          if (localTimedResult.isFailure) {
            yield Err(localTimedResult.failureOrNull!);
            continue;
          }

          final localTimed = localTimedResult.successOrNull;
          if (localTimed != null) {
            yield Success(
              ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
                schedule,
                localTimed,
              ),
            );
            continue;
          }

          // Fallback to fetching canonical preparation from source
          final loadPrepResult =
          await _loadPreparationByScheduleIdUseCase(schedule.id);
          if (loadPrepResult.isFailure) {
            yield Err(loadPrepResult.failureOrNull!);
            continue;
          }

          final preparationResult =
              await _getPreparationByScheduleIdUseCase(schedule.id);
          if (preparationResult.isFailure) {
            yield Err(preparationResult.failureOrNull!);
            continue;
          }

          final preparation = preparationResult.successOrNull!;
          final scheduleWithPreparation =
              ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
                  schedule,
                  PreparationWithTimeEntity.fromPreparation(preparation));
          yield Success(scheduleWithPreparation);
        } catch (e) {
          yield const Success(null);
          continue;
        }
      } else {
        yield const Success(null);
      }
    }
  }
}
