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
  Stream<ScheduleEntity> getScheduleById(int id) async* {
    try {
      final streamController = StreamController<ScheduleEntity>();
      final localScheduleEntity = scheduleLocalDataSource.getScheduleById(id);
      final remoteScheduleEntity = scheduleRemoteDataSource.getScheduleById(id);

      bool isFirstResponse = true;

      localScheduleEntity.then((localScheduleEntity) {
        if (isFirstResponse) {
          isFirstResponse = false;
          streamController.add(localScheduleEntity);
        }
      });

      remoteScheduleEntity.then((remoteScheduleEntity) async {
        if (isFirstResponse) {
          isFirstResponse = false;
          streamController.add(remoteScheduleEntity);
        } else {
          if (await localScheduleEntity != remoteScheduleEntity) {
            streamController.add(remoteScheduleEntity);
            await scheduleLocalDataSource.updateSchedule(remoteScheduleEntity);
          }
        }
      });

      await Future.wait([localScheduleEntity, remoteScheduleEntity]);
      yield* streamController.stream;
    } catch (e) {
      rethrow;
    }
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
