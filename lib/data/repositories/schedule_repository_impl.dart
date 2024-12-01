import 'dart:async';

import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:collection/collection.dart';
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
  Future<void> createSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.createSchedule(schedule);
      await scheduleLocalDataSource.createSchedule(schedule);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.deleteSchedule(schedule);
      //await scheduleLocalDataSource.deleteSchedule(schedule);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<ScheduleEntity> getScheduleById(String id) async* {
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
      yield* streamController.stream;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate) async* {
    try {
      final streamController = StreamController<List<ScheduleEntity>>();
      // final localScheduleEntityList =
      //     scheduleLocalDataSource.getSchedulesByDate(startDate, endDate);
      final remoteScheduleEntityList =
          scheduleRemoteDataSource.getSchedulesByDate(startDate, endDate);

      bool isFirstResponse = true;

      // localScheduleEntityList.then((localSchedules) {
      //   if (isFirstResponse) {
      //     isFirstResponse = false;
      //     streamController.add(localSchedules);
      //   }
      // });

      remoteScheduleEntityList.then((remoteSchedules) async {
        if (isFirstResponse) {
          isFirstResponse = false;
          streamController.add(remoteSchedules);
        } else {
          // final localData = await localScheduleEntityList;
          // //update local data
          // for (final remoteSchedule in remoteSchedules) {
          //   final localSchedule = localData
          //       .firstWhereOrNull((element) => element.id == remoteSchedule.id);
          //   if (localSchedule != remoteSchedule) {
          //     await scheduleLocalDataSource.updateSchedule(remoteSchedule);
          //   }
          // }

          streamController.add(remoteSchedules);
        }
      });
      yield* streamController.stream;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.updateSchedule(schedule);
      //await scheduleLocalDataSource.updateSchedule(schedule);
    } catch (e) {
      rethrow;
    }
  }
}
