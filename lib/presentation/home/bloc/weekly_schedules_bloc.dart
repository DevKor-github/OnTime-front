import 'package:on_time_front/core/time/device_civil_day.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_week_use_case.dart';

part 'weekly_schedules_event.dart';
part 'weekly_schedules_state.dart';

@Injectable()
class WeeklySchedulesBloc
    extends Bloc<WeeklySchedulesEvent, WeeklySchedulesState> {
  WeeklySchedulesBloc(
    this._loadSchedulesForWeekUseCase,
    this._getSchedulesByDateUseCase,
  ) : super(WeeklySchedulesState()) {
    on<WeeklySchedulesSubscriptionRequested>((event, emit) async {
      emit(state.copyWith(status: () => WeeklySchedulesStatus.loading));

      try {
        await _loadSchedulesForWeekUseCase(event.date);
      } catch (_) {
        emit(state.copyWith(status: () => WeeklySchedulesStatus.error));
        return;
      }

      await emit.forEach(
        _getSchedulesByDateUseCase(
          CivilDateTime.fromFields(
            event.startDate,
          ).toUtcCarrier().subtract(const Duration(days: 2)),
          CivilDateTime.fromFields(
            event.endDate,
          ).toUtcCarrier().add(const Duration(days: 2)),
        ),
        onData: (schedules) => state.copyWith(
          status: () => WeeklySchedulesStatus.success,
          schedules: () => schedules,
        ),
        onError: (error, stackTrace) =>
            state.copyWith(status: () => WeeklySchedulesStatus.error),
      );
    });
  }

  final LoadSchedulesForWeekUseCase _loadSchedulesForWeekUseCase;
  final GetSchedulesByDateUseCase _getSchedulesByDateUseCase;
}
