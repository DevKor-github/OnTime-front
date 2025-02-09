library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';

part 'schedule_by_date_event.dart';
part 'schedule_by_date_state.dart';

class ScheduleByDateBloc
    extends Bloc<ScheduleByDateEvent, ScheduleByDateState> {
  final ScheduleRemoteDataSource scheduleRemoteDataSource;

  ScheduleByDateBloc({required this.scheduleRemoteDataSource})
      : super(ScheduleListInitial()) {
    on<ScheduleListFetchEvent>(_onFetchEvent);
  }

  Future<void> _onFetchEvent(
      ScheduleListFetchEvent event, Emitter<ScheduleByDateState> emit) async {
    emit(ScheduleListLoadInProgress());
    try {
      // 서버에서 오늘 날짜 기준 목록을 받아옴
      final schedules = await scheduleRemoteDataSource.getSchedulesByDate(
        DateTime.now(),
        null,
      );
      emit(ScheduleListLoadSuccess(schedules: schedules));
    } catch (e) {
      emit(ScheduleListError(errorMessage: e.toString()));
    }
  }
}
