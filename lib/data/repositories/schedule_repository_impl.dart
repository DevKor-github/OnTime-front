import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleLocalDataSource scheduleLocalDataSource;
  final ScheduleRemoteDataSource scheduleRemoteDataSource;

  late final _scheduleStreamController =
      BehaviorSubject<Set<ScheduleEntity>>.seeded(
    const <ScheduleEntity>{},
  );

  ScheduleRepositoryImpl({
    required this.scheduleLocalDataSource,
    required this.scheduleRemoteDataSource,
  });

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream =>
      _scheduleStreamController.asBroadcastStream();

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.createSchedule(schedule);
      //await scheduleLocalDataSource.createSchedule(schedule);
      _scheduleStreamController
          .add(Set.from(_scheduleStreamController.value)..add(schedule));
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
      _scheduleStreamController
          .add(Set.from(_scheduleStreamController.value)..add(schedule));
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
      _scheduleStreamController
          .add(Set.from(_scheduleStreamController.value)..addAll(schedules));
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
