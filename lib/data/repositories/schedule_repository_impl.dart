import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleLocalDataSource scheduleLocalDataSource;
  final ScheduleRemoteDataSource scheduleRemoteDataSource;
  final TimedPreparationRepository timedPreparationRepository;

  late final _scheduleStreamController =
      BehaviorSubject<Set<ScheduleEntity>>.seeded(const <ScheduleEntity>{});

  ScheduleRepositoryImpl({
    required this.scheduleLocalDataSource,
    required this.scheduleRemoteDataSource,
    required this.timedPreparationRepository,
  });

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream =>
      _scheduleStreamController.asBroadcastStream();

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.createSchedule(schedule);
      //await scheduleLocalDataSource.createSchedule(schedule);
      _scheduleStreamController.add(
        Set.from(_scheduleStreamController.value)..add(schedule),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.deleteSchedule(schedule);
      await _clearTimedPreparationSafe(schedule.id);
      //await scheduleLocalDataSource.deleteSchedule(schedule);
      _scheduleStreamController.add(
        Set.from(_scheduleStreamController.value)..remove(schedule),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    try {
      final schedule = await scheduleRemoteDataSource.getScheduleById(id);
      if (_isEnded(schedule.doneStatus)) {
        await _clearTimedPreparationSafe(schedule.id);
      }
      _scheduleStreamController.add(
        Set.from(_scheduleStreamController.value)..add(schedule),
      );
      return schedule;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    try {
      final schedules = await scheduleRemoteDataSource.getSchedulesByDate(
        startDate,
        endDate,
      );
      for (final schedule in schedules) {
        if (_isEnded(schedule.doneStatus)) {
          await _clearTimedPreparationSafe(schedule.id);
        }
      }
      final mergedSchedules = Set<ScheduleEntity>.from(
        _scheduleStreamController.value,
      );
      for (final schedule in schedules) {
        mergedSchedules.removeWhere((existing) => existing.id == schedule.id);
        mergedSchedules.add(schedule);
      }
      _scheduleStreamController.add(mergedSchedules);
      return schedules;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.updateSchedule(schedule);
      await _clearTimedPreparationSafe(schedule.id);
      _scheduleStreamController.add(
        Set.from(_scheduleStreamController.value)
          ..remove(schedule)
          ..add(schedule),
      );
      //await scheduleLocalDataSource.updateSchedule(schedule);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {
    try {
      await scheduleRemoteDataSource.finishSchedule(scheduleId, latenessTime);
      await _clearTimedPreparationSafe(scheduleId);
      final lateStatus = latenessTime > 0
          ? ScheduleDoneStatus.lateEnd
          : ScheduleDoneStatus.normalEnd;
      final schedule = _scheduleStreamController.value.firstWhere(
        (schedule) => schedule.id == scheduleId,
      );
      _scheduleStreamController.add(
        Set.from(_scheduleStreamController.value)
          ..remove(schedule)
          ..add(schedule.copyWith(doneStatus: lateStatus)),
      );
    } catch (e) {
      rethrow;
    }
  }

  bool _isEnded(ScheduleDoneStatus doneStatus) {
    return doneStatus == ScheduleDoneStatus.normalEnd ||
        doneStatus == ScheduleDoneStatus.lateEnd ||
        doneStatus == ScheduleDoneStatus.abnormalEnd;
  }

  Future<void> _clearTimedPreparationSafe(String scheduleId) async {
    try {
      await timedPreparationRepository.clearTimedPreparation(scheduleId);
    } catch (_) {
      // Best-effort cleanup: cache invalidation must not fail schedule operations.
    }
  }
}
