import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/core/services/error_logger_service.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/data/errors/exception_to_failure_mapper.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleLocalDataSource scheduleLocalDataSource;
  final ScheduleRemoteDataSource scheduleRemoteDataSource;
  final ErrorLoggerService _errorLogger;

  late final _scheduleStreamController =
      BehaviorSubject<Result<Set<ScheduleEntity>, Failure>>.seeded(
    Success(const <ScheduleEntity>{}),
  );

  ScheduleRepositoryImpl({
    required this.scheduleLocalDataSource,
    required this.scheduleRemoteDataSource,
    required ErrorLoggerService errorLoggerService,
  }) : _errorLogger = errorLoggerService;

  @override
  Stream<Result<Set<ScheduleEntity>, Failure>> get scheduleStream =>
      _scheduleStreamController.asBroadcastStream();

  @override
  Future<Result<Unit, Failure>> createSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.createSchedule(schedule);
      //await scheduleLocalDataSource.createSchedule(schedule);
      final current =
          _scheduleStreamController.value.successOrNull ?? const <ScheduleEntity>{};
      _scheduleStreamController.add(
        Success(Set.from(current)..add(schedule)),
      );
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'createSchedule');
      _scheduleStreamController.add(Err(failure));
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> deleteSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.deleteSchedule(schedule);
      //await scheduleLocalDataSource.deleteSchedule(schedule);
      final current =
          _scheduleStreamController.value.successOrNull ?? const <ScheduleEntity>{};
      _scheduleStreamController.add(
        Success(Set.from(current)..remove(schedule)),
      );
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'deleteSchedule');
      _scheduleStreamController.add(Err(failure));
      return Err(failure);
    }
  }

  @override
  Future<Result<ScheduleEntity, Failure>> getScheduleById(String id) async {
    try {
      final schedule = await scheduleRemoteDataSource.getScheduleById(id);
      final current =
          _scheduleStreamController.value.successOrNull ?? const <ScheduleEntity>{};
      _scheduleStreamController.add(
        Success(Set.from(current)..add(schedule)),
      );
      return Success(schedule);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'getScheduleById');
      _scheduleStreamController.add(Err(failure));
      return Err(failure);
    }
  }

  @override
  Future<Result<List<ScheduleEntity>, Failure>> getSchedulesByDate(
      DateTime startDate, DateTime? endDate) async {
    try {
      final schedules =
          await scheduleRemoteDataSource.getSchedulesByDate(startDate, endDate);
      final current =
          _scheduleStreamController.value.successOrNull ?? const <ScheduleEntity>{};
      _scheduleStreamController.add(
        Success(Set.from(current)..addAll(schedules)),
      );
      return Success(schedules);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'getSchedulesByDate');
      _scheduleStreamController.add(Err(failure));
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> updateSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.updateSchedule(schedule);
      final current =
          _scheduleStreamController.value.successOrNull ?? const <ScheduleEntity>{};
      _scheduleStreamController.add(
        Success(Set.from(current)..remove(schedule)..add(schedule)),
      );
      //await scheduleLocalDataSource.updateSchedule(schedule);
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'updateSchedule');
      _scheduleStreamController.add(Err(failure));
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> finishSchedule(
      String scheduleId, int latenessTime) async {
    try {
      await scheduleRemoteDataSource.finishSchedule(scheduleId, latenessTime);
      final lateStatus = latenessTime > 0
          ? ScheduleDoneStatus.lateEnd
          : ScheduleDoneStatus.normalEnd;
      final current =
          _scheduleStreamController.value.successOrNull ?? const <ScheduleEntity>{};
      final schedule = current.firstWhere((schedule) => schedule.id == scheduleId);
      _scheduleStreamController.add(
        Success(Set.from(current)
          ..remove(schedule)
          ..add(schedule.copyWith(doneStatus: lateStatus))),
      );
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'finishSchedule');
      _scheduleStreamController.add(Err(failure));
      return Err(failure);
    }
  }
}
