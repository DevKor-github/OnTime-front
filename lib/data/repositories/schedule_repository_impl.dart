import 'dart:async';

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
  Future<ScheduleEntity> getScheduleById(String id) async {
    try {
      final schedule = await scheduleRemoteDataSource.getScheduleById(id);
      return schedule;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate) async {
    try {
      final schedules =
          await scheduleRemoteDataSource.getSchedulesByDate(startDate, endDate);
      return schedules;
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
