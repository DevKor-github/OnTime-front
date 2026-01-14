import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';

abstract interface class ScheduleRepository {
  Stream<Result<Set<ScheduleEntity>, Failure>> get scheduleStream;

  /// Create a schedule
  /// This is for creating a schedule
  Future<Result<Unit, Failure>> createSchedule(ScheduleEntity schedule);

  /// Get a List of schedules that are between the [startDate] and [endDate]
  /// if [endDate] is null, it will get all schedules after [startDate]
  /// This is for getting schedules by date
  Future<Result<List<ScheduleEntity>, Failure>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate);

  /// Get a schedule by [id]
  /// This is for getting a schedule by id
  Future<Result<ScheduleEntity, Failure>> getScheduleById(String id);

  /// Update a schedule
  /// This is for updating a schedule
  Future<Result<Unit, Failure>> updateSchedule(ScheduleEntity schedule);

  /// Delete a schedule
  /// This is for deleting a schedule
  Future<Result<Unit, Failure>> deleteSchedule(ScheduleEntity schedule);

  /// Finish a schedule with lateness time
  Future<Result<Unit, Failure>> finishSchedule(
      String scheduleId, int latenessTime);
}
