import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

abstract interface class ScheduleLocalDataSource {
  Future<void> createSchedule(ScheduleEntity scheduleEntity);

  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  );

  Future<ScheduleEntity> getScheduleById(String id);

  Future<void> updateSchedule(ScheduleEntity scheduleEntity);

  Future<void> deleteSchedule(ScheduleEntity scheduleEntity);
}

@Injectable(as: ScheduleLocalDataSource)
class ScheduleLocalDataSourceImpl implements ScheduleLocalDataSource {
  final AppDatabase appDatabase;

  ScheduleLocalDataSourceImpl({required this.appDatabase});

  @override
  Future<void> createSchedule(ScheduleEntity scheduleEntity) async {
    await appDatabase.scheduleDao.createSchedule(
      scheduleEntity.toScheduleWithPlaceRow(),
    );
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedulEntity) async {
    await appDatabase.scheduleDao.deleteSchedule(schedulEntity.toScheduleRow());
  }

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    final scheduleWithPlaceModel = await appDatabase.scheduleDao
        .getScheduleById(id);
    return scheduleWithPlaceModel.toScheduleEntity();
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    final scheduleWithPlaceModel = await appDatabase.scheduleDao
        .getSchedulesByDate(startDate, endDate);
    return scheduleWithPlaceModel.map((e) => e.toScheduleEntity()).toList();
  }

  @override
  Future<void> updateSchedule(ScheduleEntity scheduleEntity) async {
    await appDatabase.scheduleDao.updateSchedule(
      scheduleEntity.toScheduleRow(),
    );
  }
}
