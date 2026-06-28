import 'dart:async';

import 'package:collection/collection.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleRemoteDataSource scheduleRemoteDataSource;
  final TimedPreparationRepository timedPreparationRepository;

  late final _scheduleStreamController =
      BehaviorSubject<Set<ScheduleEntity>>.seeded(const <ScheduleEntity>{});
  final _rangeStreamControllers =
      <_ScheduleDateRange, BehaviorSubject<List<ScheduleEntity>>>{};
  final _scheduleListEquality = const ListEquality<ScheduleEntity>();

  ScheduleRepositoryImpl({
    required this.scheduleRemoteDataSource,
    required this.timedPreparationRepository,
  });

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream =>
      _scheduleStreamController.stream;

  @override
  Stream<List<ScheduleEntity>> watchSchedulesByDate(
    DateTime startDate,
    DateTime endDate,
  ) {
    final range = _ScheduleDateRange(startDate: startDate, endDate: endDate);
    return _rangeStreamControllers
        .putIfAbsent(
          range,
          () => BehaviorSubject<List<ScheduleEntity>>.seeded(
            _schedulesInRange(range),
          ),
        )
        .stream;
  }

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.createSchedule(schedule);
      _emitUpsertedSchedule(schedule);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {
    try {
      await scheduleRemoteDataSource.deleteSchedule(schedule);
      await _clearTimedPreparationSafe(schedule.id);
      _emitScheduleSet(
        Set.from(_scheduleStreamController.value)
          ..removeWhere((existing) => existing.id == schedule.id),
        affectedRanges: _rangesContaining(schedule.scheduleTime),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> startSchedule(String scheduleId) async {
    try {
      await scheduleRemoteDataSource.startSchedule(scheduleId);
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
      _emitUpsertedSchedule(schedule);
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
      _replaceSchedulesInRange(
        startDate: startDate,
        endDate: endDate,
        schedules: schedules,
      );
      return schedules;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateSchedule(
    ScheduleEntity schedule, {
    bool includePreparationSource = false,
  }) async {
    try {
      await scheduleRemoteDataSource.updateSchedule(
        schedule,
        includePreparationSource: includePreparationSource,
      );
      await _clearTimedPreparationSafe(schedule.id);
      final refreshedSchedule = await scheduleRemoteDataSource.getScheduleById(
        schedule.id,
      );
      if (_isEnded(refreshedSchedule.doneStatus)) {
        await _clearTimedPreparationSafe(refreshedSchedule.id);
      }
      _emitUpsertedSchedule(refreshedSchedule);
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
      _emitUpsertedSchedule(schedule.copyWith(doneStatus: lateStatus));
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

  void _emitUpsertedSchedule(ScheduleEntity schedule) {
    final existingSchedules = _scheduleStreamController.value.where(
      (existing) => existing.id == schedule.id,
    );
    final previousSchedule = existingSchedules.isEmpty
        ? null
        : existingSchedules.first;
    final nextSchedules =
        Set<ScheduleEntity>.from(_scheduleStreamController.value)
          ..removeWhere((existing) => existing.id == schedule.id)
          ..add(schedule);
    _emitScheduleSet(
      nextSchedules,
      affectedRanges: _rangesContainingAny([
        schedule.scheduleTime,
        if (previousSchedule != null) previousSchedule.scheduleTime,
      ]),
    );
  }

  void _replaceSchedulesInRange({
    required DateTime startDate,
    required DateTime? endDate,
    required Iterable<ScheduleEntity> schedules,
  }) {
    final nextSchedules =
        Set<ScheduleEntity>.from(_scheduleStreamController.value)..removeWhere(
          (existing) =>
              !existing.scheduleTime.isBefore(startDate) &&
              (endDate == null || existing.scheduleTime.isBefore(endDate)),
        );
    for (final schedule in schedules) {
      nextSchedules.add(schedule);
    }
    final loadedRange = endDate == null
        ? null
        : _ScheduleDateRange(startDate: startDate, endDate: endDate);
    _emitScheduleSet(
      nextSchedules,
      affectedRanges: loadedRange == null
          ? _rangeStreamControllers.keys
          : _rangesOverlapping(loadedRange),
    );
  }

  void _emitScheduleSet(
    Set<ScheduleEntity> nextSchedules, {
    required Iterable<_ScheduleDateRange> affectedRanges,
  }) {
    _scheduleStreamController.add(nextSchedules);
    _publishRangeUpdates(affectedRanges);
  }

  Iterable<_ScheduleDateRange> _rangesContaining(DateTime scheduleTime) {
    return _rangeStreamControllers.keys.where(
      (range) => range.contains(scheduleTime),
    );
  }

  Iterable<_ScheduleDateRange> _rangesContainingAny(
    Iterable<DateTime> scheduleTimes,
  ) {
    return _rangeStreamControllers.keys.where(
      (range) => scheduleTimes.any(range.contains),
    );
  }

  Iterable<_ScheduleDateRange> _rangesOverlapping(_ScheduleDateRange range) {
    return _rangeStreamControllers.keys.where(range.overlaps);
  }

  void _publishRangeUpdates(Iterable<_ScheduleDateRange> affectedRanges) {
    for (final range in affectedRanges) {
      final controller = _rangeStreamControllers[range];
      if (controller == null || controller.isClosed) {
        continue;
      }
      final nextSchedules = _schedulesInRange(range);
      if (!_scheduleListEquality.equals(controller.value, nextSchedules)) {
        controller.add(nextSchedules);
      }
    }
  }

  List<ScheduleEntity> _schedulesInRange(_ScheduleDateRange range) {
    final schedules = _scheduleStreamController.value
        .where((schedule) => range.contains(schedule.scheduleTime))
        .toList();
    schedules.sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
    return schedules;
  }
}

class _ScheduleDateRange {
  const _ScheduleDateRange({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;

  bool contains(DateTime dateTime) {
    return dateTime.compareTo(startDate) >= 0 && dateTime.isBefore(endDate);
  }

  bool overlaps(_ScheduleDateRange other) {
    return startDate.isBefore(other.endDate) &&
        other.startDate.isBefore(endDate);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _ScheduleDateRange &&
            startDate == other.startDate &&
            endDate == other.endDate;
  }

  @override
  int get hashCode => Object.hash(startDate, endDate);
}
