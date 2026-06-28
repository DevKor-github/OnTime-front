import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';

abstract interface class ScheduleLocalDataSource {
  Future<void> createSchedule(ScheduleWithPlace schedule);

  Future<List<ScheduleWithPlace>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  );

  Future<ScheduleWithPlace> getScheduleById(String id);

  Future<void> updateSchedule(Schedule schedule);

  Future<void> deleteSchedule(Schedule schedule);
}

// Not registered with DI; schedule repository persistence is remote-only.
class ScheduleLocalDataSourceImpl implements ScheduleLocalDataSource {
  final AppDatabase appDatabase;

  ScheduleLocalDataSourceImpl({required this.appDatabase});

  @override
  Future<void> createSchedule(ScheduleWithPlace schedule) async {
    await appDatabase.scheduleDao.createSchedule(schedule);
  }

  @override
  Future<void> deleteSchedule(Schedule schedule) async {
    await appDatabase.scheduleDao.deleteSchedule(schedule);
  }

  @override
  Future<ScheduleWithPlace> getScheduleById(String id) async {
    return appDatabase.scheduleDao.getScheduleById(id);
  }

  @override
  Future<List<ScheduleWithPlace>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    return appDatabase.scheduleDao.getSchedulesByDate(startDate, endDate);
  }

  @override
  Future<void> updateSchedule(Schedule schedule) async {
    await appDatabase.scheduleDao.updateSchedule(schedule);
  }
}
