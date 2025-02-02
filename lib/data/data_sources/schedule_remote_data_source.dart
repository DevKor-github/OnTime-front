import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';

import 'package:on_time_front/data/models/create_schedule_request_model.dart';
import 'package:on_time_front/data/models/get_schedule_response_model.dart';
import 'package:on_time_front/data/models/update_schedule_request_model.dart';

import 'package:on_time_front/domain/entities/schedule_entity.dart';

abstract interface class ScheduleRemoteDataSource {
  Future<void> createSchedule(ScheduleEntity schedule);

  Future<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate);

  Future<ScheduleEntity> getScheduleById(String id);

  Future<void> updateSchedule(ScheduleEntity schedule);

  Future<void> deleteSchedule(ScheduleEntity schedule);
}

@Injectable(as: ScheduleRemoteDataSource)
class ScheduleRemoteDataSourceImpl implements ScheduleRemoteDataSource {
  final Dio dio;
  ScheduleRemoteDataSourceImpl(this.dio);

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    try {
      CreateScheduleRequestModel createScheduleModel =
          CreateScheduleRequestModel.fromEntity(schedule);
      final result = await dio.post(Endpoint.createSchedule,
          data: createScheduleModel.toJson());
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error creating schedule worng status code');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateSchedule(ScheduleEntity schedule) async {
    try {
      UpdateScheduleRequestModel updateScheduleModel =
          UpdateScheduleRequestModel.fromEntity(schedule);
      final result = await dio.put(Endpoint.updateSchedule,
          data: updateScheduleModel.toJson());
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error updating schedule');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {
    try {
      final result = await dio.delete(Endpoint.deleteSchedule(schedule.id));
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error deleting schedule');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    try {
      final result = await dio.get(Endpoint.getSchedule(id));
      if (result.statusCode == 200) {
        final GetScheduleResponseModel schedule =
            GetScheduleResponseModel.fromJson(result.data["data"]);
        return schedule.toEntity();
      } else {
        throw Exception('Error getting schedules');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate) async {
    try {
      final result =
          await dio.get(Endpoint.getSchedulesByDate, queryParameters: {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String() ?? '',
      });
      if (result.statusCode == 200) {
        final List<ScheduleEntity> schedules = result.data["data"]
            .map<ScheduleEntity>(
                (e) => GetScheduleResponseModel.fromJson(e).toEntity())
            .toList();
        return schedules;
      } else {
        throw Exception('Error getting schedules');
      }
    } catch (e) {
      rethrow;
    }
  }
}
