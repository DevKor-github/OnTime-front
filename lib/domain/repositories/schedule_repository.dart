import 'package:on_time_front/domain/entities/schedule_entity.dart';

abstract interface class ScheduleRepository {
  /// Create a schedule
  Future<void> createSchedule(ScheduleEntity schedule);

  /// Get a List of schedules that are between the [startDate] and [endDate]
  /// if [endDate] is null, it will get all schedules after [startDate]
  Stream<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate);

  /// Get a schedule by [id]
  Stream<ScheduleEntity> getScheduleById(int id);

  /// Update a schedule
  Future<void> updateSchedule(ScheduleEntity schedule);

  /// Delete a schedule
  Future<void> deleteSchedule(ScheduleEntity schedule);
}
