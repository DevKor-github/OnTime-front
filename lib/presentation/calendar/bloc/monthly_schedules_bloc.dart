import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
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
  ) : super(MonthlySchedulesState()) {
    on<MonthlySchedulesSubscriptionRequested>((event, emit) async {
      emit(state.copyWith(status: () => MonthlySchedulesStatus.loading));

      await _loadSchedulesForMonthUseCase(event.date);

      await emit.forEach(
        _getSchedulesByDateUseCase(event.startDate, event.endDate),
        onData: (schedules) => state.copyWith(
          status: () => MonthlySchedulesStatus.success,
          schedules: () => schedules.fold<Map<DateTime, List<ScheduleEntity>>>(
            {},
            (previousValue, element) {
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
            },
          ),
          startDate: () => event.startDate,
          endDate: () => event.endDate,
        ),
        onError: (error, stackTrace) => state.copyWith(
          status: () => MonthlySchedulesStatus.error,
        ),
      );
    });

    on<MonthlySchedulesMonthAdded>((event, emit) async {
      if (!(state.startDate!.isAfter(event.startDate) ||
          state.endDate!.isBefore(event.endDate))) {
        return;
      } else if (event.date.month !=
              state.startDate!.subtract(Duration(days: 1)).month &&
          (event.date.month != state.endDate!.month)) {
        // If the month is not consecutive, we need to load the schedules for the
        add(MonthlySchedulesSubscriptionRequested(date: event.date));
      } else {
        // If the month is not consecutive, we need to load the schedules for the
        // month and update the state with the new schedules.

        DateTime startDate = event.startDate.isBefore(state.startDate!)
            ? event.startDate
            : state.startDate!;
        DateTime endDate = event.endDate.isAfter(state.endDate!)
            ? event.endDate
            : state.endDate!;

        emit(state.copyWith(
          status: () => MonthlySchedulesStatus.loading,
          schedules: () => state.schedules,
          startDate: () => startDate,
          endDate: () => endDate,
        ));

        await _loadSchedulesForMonthUseCase(event.date);

        debugPrint('startDate: $startDate, endDate: $endDate');
        await emit.forEach(_getSchedulesByDateUseCase(startDate, endDate),
            onData: (schedules) {
          return state.copyWith(
            status: () => MonthlySchedulesStatus.success,
            schedules: () =>
                schedules.fold<Map<DateTime, List<ScheduleEntity>>>(
              {},
              (previousValue, element) {
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
              },
            ),
            startDate: () => startDate,
            endDate: () => endDate,
          );
        }, onError: (error, stackTrace) {
          return state.copyWith(
            status: () => MonthlySchedulesStatus.error,
          );
        });
      }
    });
  }

  final LoadSchedulesForMonthUseCase _loadSchedulesForMonthUseCase;
  final GetSchedulesByDateUseCase _getSchedulesByDateUseCase;
}
