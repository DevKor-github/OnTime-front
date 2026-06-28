import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/dio/api_error_message.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_month_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_preparations_use_case.dart';

part 'monthly_schedules_event.dart';
part 'monthly_schedules_state.dart';

@Injectable()
class MonthlySchedulesBloc
    extends Bloc<MonthlySchedulesEvent, MonthlySchedulesState> {
  static const int _maxPreparationPrefetchConcurrency = 4;

  MonthlySchedulesBloc(
    this._loadSchedulesForMonthUseCase,
    this._getSchedulesByDateUseCase,
    this._deleteScheduleUseCase,
    this._loadPreparationByScheduleIdUseCase,
    this._getPreparationByScheduleIdUseCase,
    this._streamPreparationsUseCase,
  ) : super(MonthlySchedulesState()) {
    on<MonthlySchedulesSubscriptionRequested>(_onSubscriptionRequested);
    on<MonthlySchedulesMonthAdded>(_onMonthAdded);
    on<MonthlySchedulesRefreshRequested>(_onRefreshRequested);
    on<MonthlySchedulesScheduleDeleted>(_onScheduleDeleted);
    on<MonthlySchedulesVisibleDateChanged>(_onVisibleDateChanged);
    on<MonthlySchedulesPreparationsPrefetchRequested>(
      _onPreparationsPrefetchRequested,
    );
    on<MonthlySchedulesPreparationsStreamChanged>(_onPreparationsStreamChanged);

    _preparationSubscription = _streamPreparationsUseCase().listen((
      preparations,
    ) {
      add(
        MonthlySchedulesPreparationsStreamChanged(preparations: preparations),
      );
    });
  }

  final LoadSchedulesForMonthUseCase _loadSchedulesForMonthUseCase;
  final GetSchedulesByDateUseCase _getSchedulesByDateUseCase;
  final DeleteScheduleUseCase _deleteScheduleUseCase;
  final LoadPreparationByScheduleIdUseCase _loadPreparationByScheduleIdUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final StreamPreparationsUseCase _streamPreparationsUseCase;

  StreamSubscription<Map<String, PreparationEntity>>? _preparationSubscription;

  Future<void> _onSubscriptionRequested(
    MonthlySchedulesSubscriptionRequested event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    emit(state.copyWith(status: () => MonthlySchedulesStatus.loading));

    try {
      await _loadSchedulesForMonthUseCase(event.date);
    } catch (_) {
      emit(state.copyWith(status: () => MonthlySchedulesStatus.error));
      return;
    }

    await emit.forEach(
      _getSchedulesByDateUseCase(event.startDate, event.endDate),
      onData: (schedules) {
        final groupedSchedules = _groupSchedulesByDate(schedules);
        final nextState = state.copyWith(
          status: () => MonthlySchedulesStatus.success,
          schedules: () => groupedSchedules,
          startDate: () => event.startDate,
          endDate: () => event.endDate,
        );
        _requestVisibleDatePreparationPrefetch(nextState);
        return nextState;
      },
      onError: (error, stackTrace) =>
          state.copyWith(status: () => MonthlySchedulesStatus.error),
    );
  }

  Future<void> _onMonthAdded(
    MonthlySchedulesMonthAdded event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    late DateTime startDate;
    late DateTime endDate;
    if (!(state.startDate!.isAfter(event.startDate) ||
        state.endDate!.isBefore(event.endDate))) {
      // If the month is already loaded, we don't need to load the schedules again.
      startDate = state.startDate!;
      endDate = state.endDate!;
    } else if (event.date.month !=
            state.startDate!.subtract(Duration(days: 1)).month &&
        (event.date.month != state.endDate!.month)) {
      // If the month is not consecutive, we need to load the schedules for the
      add(MonthlySchedulesSubscriptionRequested(date: event.date));
      return;
    } else {
      // If the month is not consecutive, we need to load the schedules for the
      // month and update the state with the new schedules.

      startDate = event.startDate.isBefore(state.startDate!)
          ? event.startDate
          : state.startDate!;
      endDate = event.endDate.isAfter(state.endDate!)
          ? event.endDate
          : state.endDate!;

      emit(
        state.copyWith(
          status: () => MonthlySchedulesStatus.loading,
          schedules: () => state.schedules,
          startDate: () => startDate,
          endDate: () => endDate,
        ),
      );

      try {
        await _loadSchedulesForMonthUseCase(event.date);
      } catch (_) {
        emit(state.copyWith(status: () => MonthlySchedulesStatus.error));
        return;
      }
    }

    AppLogger.debug('startDate: $startDate, endDate: $endDate');
    await emit.forEach(
      _getSchedulesByDateUseCase(startDate, endDate),
      onData: (schedules) {
        final groupedSchedules = _groupSchedulesByDate(schedules);
        final nextState = state.copyWith(
          status: () => MonthlySchedulesStatus.success,
          schedules: () => groupedSchedules,
          startDate: () => startDate,
          endDate: () => endDate,
        );
        _requestVisibleDatePreparationPrefetch(nextState);
        return nextState;
      },
      onError: (error, stackTrace) {
        return state.copyWith(status: () => MonthlySchedulesStatus.error);
      },
    );
  }

  Future<void> _onScheduleDeleted(
    MonthlySchedulesScheduleDeleted event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    final previousPreparationMap = Map<String, Duration>.from(
      state.preparationDurationByScheduleId,
    );
    try {
      final updatedPreparationMap = Map<String, Duration>.from(
        previousPreparationMap,
      )..remove(event.schedule.id);
      emit(
        state.copyWith(
          lastDeletedSchedule: () => event.schedule,
          preparationDurationByScheduleId: () => updatedPreparationMap,
        ),
      );
      await _deleteScheduleUseCase(event.schedule);
    } catch (e) {
      emit(
        state.copyWith(
          lastDeletedSchedule: () => null,
          preparationDurationByScheduleId: () => previousPreparationMap,
          deleteFailureMessage: () => ApiErrorMessage.fromException(e),
          deleteFailureCount: () => state.deleteFailureCount + 1,
        ),
      );
    }
  }

  Future<void> _onRefreshRequested(
    MonthlySchedulesRefreshRequested event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    try {
      await _loadSchedulesForMonthUseCase(event.date);
    } catch (_) {
      emit(state.copyWith(status: () => MonthlySchedulesStatus.error));
    }
  }

  void _onVisibleDateChanged(
    MonthlySchedulesVisibleDateChanged event,
    Emitter<MonthlySchedulesState> emit,
  ) {
    final normalizedDate = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final nextState = state.copyWith(visibleDate: () => normalizedDate);
    emit(nextState);
    _requestVisibleDatePreparationPrefetch(nextState);
  }

  Future<void> _onPreparationsPrefetchRequested(
    MonthlySchedulesPreparationsPrefetchRequested event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    final missingIds = event.scheduleIds
        .where((id) => !state.preparationDurationByScheduleId.containsKey(id))
        .toSet();
    if (missingIds.isEmpty) {
      return;
    }

    final fetchedDurations = <String, Duration>{};
    await _forEachMissingPreparationId(missingIds, (scheduleId) async {
      final duration = await _loadPreparationDuration(scheduleId);
      if (duration != null) {
        fetchedDurations[scheduleId] = duration;
      }
    });

    if (fetchedDurations.isNotEmpty && !emit.isDone) {
      final updatedMap = Map<String, Duration>.from(
        state.preparationDurationByScheduleId,
      );
      var hasUpdates = false;
      for (final entry in fetchedDurations.entries) {
        if (updatedMap.containsKey(entry.key)) {
          continue;
        }
        updatedMap[entry.key] = entry.value;
        hasUpdates = true;
      }
      if (hasUpdates) {
        emit(state.copyWith(preparationDurationByScheduleId: () => updatedMap));
      }
    }
  }

  Future<void> _forEachMissingPreparationId(
    Set<String> scheduleIds,
    Future<void> Function(String scheduleId) load,
  ) async {
    final ids = scheduleIds.toList(growable: false);
    var nextIndex = 0;
    final workerCount = ids.length < _maxPreparationPrefetchConcurrency
        ? ids.length
        : _maxPreparationPrefetchConcurrency;

    String? takeNextId() {
      if (nextIndex >= ids.length) {
        return null;
      }
      return ids[nextIndex++];
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) async {
        while (true) {
          final scheduleId = takeNextId();
          if (scheduleId == null) {
            return;
          }
          await load(scheduleId);
        }
      }),
    );
  }

  Future<Duration?> _loadPreparationDuration(String scheduleId) async {
    if (state.preparationDurationByScheduleId.containsKey(scheduleId)) {
      return null;
    }

    try {
      await _loadPreparationByScheduleIdUseCase(scheduleId);
      if (state.preparationDurationByScheduleId.containsKey(scheduleId)) {
        // Stream update already has fresher data.
        return null;
      }
      final preparation = await _getPreparationByScheduleIdUseCase(scheduleId);
      return preparation.totalDuration;
    } catch (_) {
      // Keep fallback UI when loading fails.
      return null;
    }
  }

  void _onPreparationsStreamChanged(
    MonthlySchedulesPreparationsStreamChanged event,
    Emitter<MonthlySchedulesState> emit,
  ) {
    final cachedScheduleIds = _getCachedScheduleIds(state.schedules);
    if (cachedScheduleIds.isEmpty) {
      return;
    }

    final nextDurations = Map<String, Duration>.from(
      state.preparationDurationByScheduleId,
    );
    var hasChange = false;

    for (final entry in event.preparations.entries) {
      if (!cachedScheduleIds.contains(entry.key)) {
        continue;
      }

      final nextDuration = entry.value.totalDuration;
      if (nextDurations[entry.key] != nextDuration) {
        nextDurations[entry.key] = nextDuration;
        hasChange = true;
      }
    }

    if (!hasChange) {
      return;
    }

    emit(state.copyWith(preparationDurationByScheduleId: () => nextDurations));
  }

  void _requestVisibleDatePreparationPrefetch(
    MonthlySchedulesState sourceState,
  ) {
    final visibleDate = sourceState.visibleDate;
    if (visibleDate == null) {
      return;
    }
    final scheduleIds = _getScheduleIdsForDate(
      sourceState.schedules,
      visibleDate,
    );
    if (scheduleIds.isEmpty) {
      return;
    }
    add(
      MonthlySchedulesPreparationsPrefetchRequested(scheduleIds: scheduleIds),
    );
  }

  Map<DateTime, List<ScheduleEntity>> _groupSchedulesByDate(
    List<ScheduleEntity> schedules,
  ) {
    return schedules.fold<Map<DateTime, List<ScheduleEntity>>>({}, (
      previousValue,
      element,
    ) {
      final scheduleTime = DateTime(
        element.scheduleTime.year,
        element.scheduleTime.month,
        element.scheduleTime.day,
      );
      if (previousValue.containsKey(scheduleTime)) {
        previousValue[scheduleTime]!.add(element);
      } else {
        previousValue[scheduleTime] = [element];
      }
      return previousValue;
    });
  }

  List<String> _getScheduleIdsForDate(
    Map<DateTime, List<ScheduleEntity>> schedules,
    DateTime date,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return schedules[normalizedDate]
            ?.map((schedule) => schedule.id)
            .toList(growable: false) ??
        const <String>[];
  }

  Set<String> _getCachedScheduleIds(
    Map<DateTime, List<ScheduleEntity>> schedules,
  ) {
    final ids = <String>{};
    for (final scheduleList in schedules.values) {
      for (final schedule in scheduleList) {
        ids.add(schedule.id);
      }
    }
    return ids;
  }

  @override
  Future<void> close() async {
    await _preparationSubscription?.cancel();
    return super.close();
  }
}
