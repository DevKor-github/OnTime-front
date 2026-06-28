import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/dio/api_error_message.dart';
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
    on<_MonthlySchedulesScheduleStreamChanged>(_onScheduleStreamChanged);
    on<_MonthlySchedulesScheduleStreamFailed>(_onScheduleStreamFailed);

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

  StreamSubscription<List<ScheduleEntity>>? _scheduleSubscription;
  StreamSubscription<Map<String, PreparationEntity>>? _preparationSubscription;
  int _scheduleRangeRequestId = 0;

  Future<void> _onSubscriptionRequested(
    MonthlySchedulesSubscriptionRequested event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    await _loadAndWatchCalendarMonthRange(
      loadDate: event.date,
      startDate: event.startDate,
      endDate: event.endDate,
      emit: emit,
    );
  }

  Future<void> _onMonthAdded(
    MonthlySchedulesMonthAdded event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    final currentStartDate = state.startDate;
    final currentEndDate = state.endDate;
    if (currentStartDate == null || currentEndDate == null) {
      await _loadAndWatchCalendarMonthRange(
        loadDate: event.date,
        startDate: event.startDate,
        endDate: event.endDate,
        emit: emit,
      );
      return;
    }

    final eventIsInsideCurrentRange =
        !currentStartDate.isAfter(event.startDate) &&
        !currentEndDate.isBefore(event.endDate);
    if (eventIsInsideCurrentRange) {
      return;
    }

    final eventMonth = DateTime(event.date.year, event.date.month, 1);
    final previousAdjacentMonth = DateTime(
      currentStartDate.year,
      currentStartDate.month - 1,
      1,
    );
    final nextAdjacentMonth = DateTime(
      currentEndDate.year,
      currentEndDate.month,
      1,
    );
    final eventIsAdjacent =
        eventMonth == previousAdjacentMonth || eventMonth == nextAdjacentMonth;

    if (!eventIsAdjacent) {
      await _loadAndWatchCalendarMonthRange(
        loadDate: event.date,
        startDate: event.startDate,
        endDate: event.endDate,
        emit: emit,
      );
      return;
    }

    final startDate = event.startDate.isBefore(currentStartDate)
        ? event.startDate
        : currentStartDate;
    final endDate = event.endDate.isAfter(currentEndDate)
        ? event.endDate
        : currentEndDate;

    await _loadAndWatchCalendarMonthRange(
      loadDate: event.date,
      startDate: startDate,
      endDate: endDate,
      emit: emit,
      exposeLoadingRange: true,
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
    var hasUpdates = false;

    for (final scheduleId in missingIds) {
      try {
        await _loadPreparationByScheduleIdUseCase(scheduleId);
        if (state.preparationDurationByScheduleId.containsKey(scheduleId)) {
          // Stream update already has fresher data.
          continue;
        }
        final preparation = await _getPreparationByScheduleIdUseCase(
          scheduleId,
        );
        fetchedDurations[scheduleId] = preparation.totalDuration;
        hasUpdates = true;
      } catch (_) {
        // Keep fallback UI when loading fails.
      }
    }

    if (hasUpdates) {
      final updatedMap = Map<String, Duration>.from(
        state.preparationDurationByScheduleId,
      )..addAll(fetchedDurations);
      emit(state.copyWith(preparationDurationByScheduleId: () => updatedMap));
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

  void _onScheduleStreamChanged(
    _MonthlySchedulesScheduleStreamChanged event,
    Emitter<MonthlySchedulesState> emit,
  ) {
    if (event.requestId != _scheduleRangeRequestId) {
      return;
    }

    final groupedSchedules = _groupSchedulesByDate(event.schedules);
    final nextState = state.copyWith(
      status: () => MonthlySchedulesStatus.success,
      schedules: () => groupedSchedules,
      startDate: () => event.startDate,
      endDate: () => event.endDate,
    );
    emit(nextState);
    _requestVisibleDatePreparationPrefetch(nextState);
  }

  void _onScheduleStreamFailed(
    _MonthlySchedulesScheduleStreamFailed event,
    Emitter<MonthlySchedulesState> emit,
  ) {
    if (event.requestId != _scheduleRangeRequestId) {
      return;
    }

    emit(state.copyWith(status: () => MonthlySchedulesStatus.error));
  }

  Future<void> _loadAndWatchCalendarMonthRange({
    required DateTime loadDate,
    required DateTime startDate,
    required DateTime endDate,
    required Emitter<MonthlySchedulesState> emit,
    bool exposeLoadingRange = false,
  }) async {
    final requestId = ++_scheduleRangeRequestId;
    await _cancelScheduleSubscription();

    var loadingState = state.copyWith(
      status: () => MonthlySchedulesStatus.loading,
    );
    if (exposeLoadingRange) {
      loadingState = loadingState.copyWith(
        startDate: () => startDate,
        endDate: () => endDate,
      );
    }
    emit(loadingState);

    try {
      await _loadSchedulesForMonthUseCase(loadDate);
    } catch (_) {
      if (requestId == _scheduleRangeRequestId) {
        emit(state.copyWith(status: () => MonthlySchedulesStatus.error));
      }
      return;
    }

    if (requestId != _scheduleRangeRequestId) {
      return;
    }

    _scheduleSubscription = _getSchedulesByDateUseCase(startDate, endDate)
        .listen(
          (schedules) {
            if (!isClosed && requestId == _scheduleRangeRequestId) {
              add(
                _MonthlySchedulesScheduleStreamChanged(
                  requestId: requestId,
                  startDate: startDate,
                  endDate: endDate,
                  schedules: schedules,
                ),
              );
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!isClosed && requestId == _scheduleRangeRequestId) {
              add(_MonthlySchedulesScheduleStreamFailed(requestId: requestId));
            }
          },
        );
  }

  Future<void> _cancelScheduleSubscription() async {
    await _scheduleSubscription?.cancel();
    _scheduleSubscription = null;
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
    await _cancelScheduleSubscription();
    await _preparationSubscription?.cancel();
    return super.close();
  }
}
