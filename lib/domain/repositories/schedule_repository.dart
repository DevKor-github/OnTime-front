import 'package:on_time_front/domain/entities/schedule_entity.dart';

abstract interface class ScheduleRepository {
  Stream<Set<ScheduleEntity>> get scheduleStream;

  /// Create a schedule
  /// This is for creating a schedule
  Future<void> createSchedule(ScheduleEntity schedule);

  /// Get a List of schedules that are between the [startDate] and [endDate]
  /// if [endDate] is null, it will get all schedules after [startDate]
  /// This is for getting schedules by date
  Future<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate);

  /// Get a schedule by [id]
  /// This is for getting a schedule by id
  Future<ScheduleEntity> getScheduleById(String id);

  /// Update a schedule
  /// This is for updating a schedule
  Future<void> updateSchedule(ScheduleEntity schedule);

  /// Delete a schedule
  /// This is for deleting a schedule
  Future<void> deleteSchedule(ScheduleEntity schedule);
}
