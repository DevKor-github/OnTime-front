import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';

import 'package:on_time_front/data/models/create_schedule_request_model.dart';
import 'package:on_time_front/data/models/get_schedule_response_model.dart';
import 'package:on_time_front/data/models/update_schedule_request_model.dart';

abstract interface class ScheduleRemoteDataSource {
  Future<void> createSchedule(CreateScheduleRequestModel schedule);

  Future<List<GetScheduleResponseModel>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  );

  Future<GetScheduleResponseModel> getScheduleById(String id);

  Future<void> updateSchedule(UpdateScheduleRequestModel schedule);

  Future<void> deleteSchedule(String scheduleId);

  Future<void> startSchedule(String scheduleId);

  Future<void> finishSchedule(String scheduleId, int latenessTime);
}

@Injectable(as: ScheduleRemoteDataSource)
class ScheduleRemoteDataSourceImpl implements ScheduleRemoteDataSource {
  final Dio dio;
  ScheduleRemoteDataSourceImpl(this.dio);

  @override
  Future<void> createSchedule(CreateScheduleRequestModel schedule) async {
    try {
      final result = await dio.post(
        Endpoint.createSchedule,
        data: schedule.toJson(),
      );
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
  Future<void> updateSchedule(UpdateScheduleRequestModel schedule) async {
    try {
      final result = await dio.put(
        Endpoint.updateSchedule(schedule.scheduleId),
        data: schedule.toJson(),
      );
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
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      final result = await dio.delete(Endpoint.deleteScheduleById(scheduleId));
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
  Future<void> startSchedule(String scheduleId) async {
    try {
      final result = await dio.post(Endpoint.startSchedule(scheduleId));
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error starting schedule');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {
    try {
      final result = await dio.put(
        Endpoint.finishSchedule(scheduleId),
        data: {'scheduleId': scheduleId, 'latenessTime': latenessTime},
      );
      if (result.statusCode == 200) {
        return;
      } else {
        throw Exception('Error finishing schedule');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<GetScheduleResponseModel> getScheduleById(String id) async {
    try {
      final result = await dio.get(Endpoint.getScheduleById(id));
      if (result.statusCode == 200) {
        final GetScheduleResponseModel schedule =
            GetScheduleResponseModel.fromJson(result.data["data"]);
        return schedule;
      } else {
        throw Exception('Error getting schedules');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<GetScheduleResponseModel>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    try {
      final result = await dio.get(
        Endpoint.getSchedulesByDate,
        queryParameters: {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate?.toIso8601String() ?? '',
        },
      );
      if (result.statusCode == 200) {
        final List<GetScheduleResponseModel> schedules = result.data["data"]
            .map<GetScheduleResponseModel>(
              (e) => GetScheduleResponseModel.fromJson(e),
            )
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
