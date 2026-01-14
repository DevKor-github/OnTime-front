import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_month_use_case.dart';

part 'monthly_schedules_event.dart';
part 'monthly_schedules_state.dart';

@Injectable()
class MonthlySchedulesBloc
    extends Bloc<MonthlySchedulesEvent, MonthlySchedulesState> {
  MonthlySchedulesBloc(
    this._loadSchedulesForMonthUseCase,
    this._getSchedulesByDateUseCase,
    this._deleteScheduleUseCase,
  ) : super(MonthlySchedulesState()) {
    on<MonthlySchedulesSubscriptionRequested>(_onSubscriptionRequested);
    on<MonthlySchedulesMonthAdded>(_onMonthAdded);
    on<MonthlySchedulesScheduleDeleted>(_onScheduleDeleted);
  }

  final LoadSchedulesForMonthUseCase _loadSchedulesForMonthUseCase;
  final GetSchedulesByDateUseCase _getSchedulesByDateUseCase;
  final DeleteScheduleUseCase _deleteScheduleUseCase;

  Map<DateTime, List<ScheduleEntity>> _groupByDay(
      List<ScheduleEntity> schedules) {
    final map = <DateTime, List<ScheduleEntity>>{};
    for (final s in schedules) {
      final day = DateTime(s.scheduleTime.year, s.scheduleTime.month, s.scheduleTime.day);
      (map[day] ??= <ScheduleEntity>[]).add(s);
    }
    return map;
  }

  Future<void> _onSubscriptionRequested(
    MonthlySchedulesSubscriptionRequested event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    emit(state.copyWith(status: () => MonthlySchedulesStatus.loading));

    final loadResult = await _loadSchedulesForMonthUseCase(event.date);
    if (loadResult.isFailure) {
      emit(state.copyWith(status: () => MonthlySchedulesStatus.error));
      return;
    }

    await emit.forEach(
      _getSchedulesByDateUseCase(event.startDate, event.endDate),
      onData: (result) {
        if (result.isFailure) {
          return state.copyWith(status: () => MonthlySchedulesStatus.error);
        }
        final list = result.successOrNull ?? const <ScheduleEntity>[];
        return state.copyWith(
          status: () => MonthlySchedulesStatus.success,
          schedules: () => _groupByDay(list),
          startDate: () => event.startDate,
          endDate: () => event.endDate,
        );
      },
      onError: (error, stackTrace) => state.copyWith(
        status: () => MonthlySchedulesStatus.error,
      ),
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

      emit(state.copyWith(
        status: () => MonthlySchedulesStatus.loading,
        schedules: () => state.schedules,
        startDate: () => startDate,
        endDate: () => endDate,
      ));

      final loadResult = await _loadSchedulesForMonthUseCase(event.date);
      if (loadResult.isFailure) {
        emit(state.copyWith(status: () => MonthlySchedulesStatus.error));
        return;
      }
    }

    debugPrint('startDate: $startDate, endDate: $endDate');
    await emit.forEach(
      _getSchedulesByDateUseCase(startDate, endDate),
      onData: (result) {
        if (result.isFailure) {
          return state.copyWith(status: () => MonthlySchedulesStatus.error);
        }
        final list = result.successOrNull ?? const <ScheduleEntity>[];
        return state.copyWith(
          status: () => MonthlySchedulesStatus.success,
          schedules: () => _groupByDay(list),
          startDate: () => startDate,
          endDate: () => endDate,
        );
      },
      onError: (error, stackTrace) {
        return state.copyWith(
          status: () => MonthlySchedulesStatus.error,
        );
      },
    );
  }

  Future<void> _onScheduleDeleted(
    MonthlySchedulesScheduleDeleted event,
    Emitter<MonthlySchedulesState> emit,
  ) async {
    emit(state.copyWith(
      lastDeletedSchedule: () => event.schedule,
    ));

    final result = await _deleteScheduleUseCase(event.schedule);
    if (result.isFailure) {
      emit(state.copyWith(
        status: () => MonthlySchedulesStatus.error,
      ));
    }
  }
}
