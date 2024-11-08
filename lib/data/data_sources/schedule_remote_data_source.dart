import 'package:on_time_front/domain/entities/schedule_entity.dart';

abstract interface class ScheduleRemoteDataSource {
  Future<void> createSchedule(ScheduleEntity schedule);

  Future<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate);

  Future<ScheduleEntity> getScheduleById(String id);

  Future<void> updateSchedule(ScheduleEntity schedule);

  Future<void> deleteSchedule(ScheduleEntity schedule);
}
