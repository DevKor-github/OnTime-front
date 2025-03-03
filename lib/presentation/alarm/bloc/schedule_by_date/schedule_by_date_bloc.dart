library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';

part 'schedule_by_date_event.dart';
part 'schedule_by_date_state.dart';

@injectable
class ScheduleByDateBloc
    extends Bloc<ScheduleByDateEvent, ScheduleByDateState> {
  final GetSchedulesByDateUseCase getSchedulesByDateUseCase;

  ScheduleByDateBloc({required this.getSchedulesByDateUseCase})
      : super(ScheduleByDateInitial()) {
    on<ScheduleByDateFetchEvent>(_onFetchEvent);
  }

  Future<void> _onFetchEvent(
      ScheduleByDateFetchEvent event, Emitter<ScheduleByDateState> emit) async {
    emit(ScheduleByDateLoadInProgress());
    try {
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 1));

      getSchedulesByDateUseCase(startDate, endDate).listen(
        (schedules) {
          emit(ScheduleByDateLoadSuccess(schedules: schedules));
        },
        onError: (error) {
          emit(ScheduleByDateLoadFailure(errorMessage: error.toString()));
        },
      );
    } catch (e) {
      emit(ScheduleByDateLoadFailure(errorMessage: e.toString()));
    }
  }
}
