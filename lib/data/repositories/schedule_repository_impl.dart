import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleLocalDataSource scheduleLocalDataSource;
  final ScheduleRemoteDataSource scheduleRemoteDataSource;

  ScheduleRepositoryImpl({
    required this.scheduleLocalDataSource,
    required this.scheduleRemoteDataSource,
  });

  @override
  Future<void> createSchedule(ScheduleEntity schedule, int userId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) {
    throw UnimplementedError();
  }

  @override
  Stream<ScheduleEntity> getScheduleById(int id) {
    throw UnimplementedError();
  }

  @override
  Stream<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateSchedule(ScheduleEntity schedule) {
    throw UnimplementedError();
  }
}
