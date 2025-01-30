import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:uuid/uuid.dart';

part 'schedule_form_event.dart';
part 'schedule_form_state.dart';

@Injectable()
class ScheduleFormBloc extends Bloc<ScheduleFormEvent, ScheduleFormState> {
  ScheduleFormBloc() : super(ScheduleFormState()) {
    on<ScheduleFormEditRequested>(_onEditRequested);
    on<ScheduleFormCreateRequested>(_onCreateRequested);
    on<ScheduleFormScheduleNameChanged>(_onScheduleNameChanged);
    on<ScheduleFormScheduleDateChanged>(_onScheduleDateChanged);
    on<ScheduleFormScheduleTimeChanged>(_onScheduleTimeChanged);
    on<ScheduleFormPlaceNameChanged>(_onPlaceNameChanged);
    on<ScheduleFormMoveTimeChanged>(_onMoveTimeChanged);
    on<ScheduleFormScheduleSpareTimeChanged>(_onScheduleSpareTimeChanged);
    on<ScheduleFormSaved>(_onSaved);
  }

  Future<void> _onEditRequested(
    ScheduleFormEditRequested event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(
      id: event.schedule.id,
      placeName: event.schedule.place.placeName,
      scheduleName: event.schedule.scheduleName,
      scheduleTime: event.schedule.scheduleTime,
      moveTime: event.schedule.moveTime,
      isChanged: event.schedule.isChanged,
      scheduleSpareTime: event.schedule.scheduleSpareTime,
      scheduleNote: event.schedule.scheduleNote,
      spareTime: event.schedule.scheduleSpareTime,
    ));
  }

  Future<void> _onCreateRequested(
    ScheduleFormCreateRequested event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(
      id: Uuid().v7(),
      placeName: null,
      scheduleName: null,
      scheduleTime: null,
      moveTime: null,
      isChanged: null,
      scheduleSpareTime: null,
      scheduleNote: null,
      spareTime: null,
    ));
  }

  Future<void> _onScheduleNameChanged(
    ScheduleFormScheduleNameChanged event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(scheduleName: event.scheduleName));
  }

  Future<void> _onScheduleDateChanged(
    ScheduleFormScheduleDateChanged event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(
        scheduleTime: state.scheduleTime?.copyWith(
              year: event.scheduleDate.year,
              month: event.scheduleDate.month,
              day: event.scheduleDate.day,
            ) ??
            event.scheduleDate));
  }

  Future<void> _onScheduleTimeChanged(
    ScheduleFormScheduleTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(
        scheduleTime: state.scheduleTime?.copyWith(
              hour: event.scheduleTime.hour,
              minute: event.scheduleTime.minute,
            ) ??
            event.scheduleTime));
  }

  Future<void> _onPlaceNameChanged(
    ScheduleFormPlaceNameChanged event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(placeName: event.placeName));
  }

  Future<void> _onMoveTimeChanged(
    ScheduleFormMoveTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(moveTime: event.moveTime));
  }

  Future<void> _onScheduleSpareTimeChanged(
    ScheduleFormScheduleSpareTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(scheduleSpareTime: event.scheduleSpareTime));
  }

  Future<void> _onSaved(
    ScheduleFormSaved event,
    Emitter<ScheduleFormState> emit,
  ) async {}
}
