import 'package:dio/dio.dart';
import 'package:on_time_front/data/models/create_schedule_model.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

abstract interface class ScheduleRemoteDataSource {
  Future<void> createSchedule(ScheduleEntity schedule);

  Future<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate);

  Future<ScheduleEntity> getScheduleById(String id);

  Future<void> updateSchedule(ScheduleEntity schedule);

  Future<void> deleteSchedule(ScheduleEntity schedule);
}

class ScheduleRemoteDataSourceImpl implements ScheduleRemoteDataSource {
  final Dio dio;
  ScheduleRemoteDataSourceImpl(this.dio);

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    try {
      CreateScheduleModel createScheduleModel =
          CreateScheduleModel.fromEntity(schedule);
      final result =
          await dio.post('/schedules/add', data: createScheduleModel.toJson());
      if (result.statusCode == 201) {
        return;
      } else {
        throw Exception('Error creating schedule');
      }
    } catch (e) {
      throw Exception('Error creating schedule');
    }
  }

  @override
  Future<void> updateSchedule(ScheduleEntity schedule) async {
    try {
      CreateScheduleModel createScheduleModel =
          CreateScheduleModel.fromEntity(schedule);
      final result = await dio.put('/schedules/${schedule.id}',
          data: createScheduleModel.toJson());
      if (result.statusCode == 204) {
        return;
      } else {
        throw Exception('Error updating schedule');
      }
    } catch (e) {
      throw Exception('Error updating schedule');
    }
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {
    try {
      final result = await dio.delete('/schedules/${schedule.id}');
      if (result.statusCode == 204) {
        return;
      } else {
        throw Exception('Error deleting schedule');
      }
    } catch (e) {
      throw Exception('Error deleting schedule');
    }
  }

  @override
  Future<ScheduleEntity> getScheduleById(String id) {
    // TODO: implement getScheduleById
    throw UnimplementedError();
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate) {
    // TODO: implement getSchedulesByDate
    throw UnimplementedError();
  }
}
