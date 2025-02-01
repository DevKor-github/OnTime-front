import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:uuid/uuid.dart';

part 'schedule_form_event.dart';
part 'schedule_form_state.dart';

@Injectable()
class ScheduleFormBloc extends Bloc<ScheduleFormEvent, ScheduleFormState> {
  ScheduleFormBloc(this._getPreparationByScheduleIdUseCase,
      this._getDefaultPreparationUseCase)
      : super(ScheduleFormState()) {
    on<ScheduleFormEditRequested>(_onEditRequested);
    on<ScheduleFormCreateRequested>(_onCreateRequested);
    on<ScheduleFormScheduleNameChanged>(_onScheduleNameChanged);
    on<ScheduleFormScheduleDateChanged>(_onScheduleDateChanged);
    on<ScheduleFormScheduleTimeChanged>(_onScheduleTimeChanged);
    on<ScheduleFormPlaceNameChanged>(_onPlaceNameChanged);
    on<ScheduleFormMoveTimeChanged>(_onMoveTimeChanged);
    on<ScheduleFormScheduleSpareTimeChanged>(_onScheduleSpareTimeChanged);
    on<ScheduleFormPreparationChanged>(_onPreparationChanged);
    on<ScheduleFormSaved>(_onSaved);
  }

  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final GetDefaultPreparationUseCase _getDefaultPreparationUseCase;

  Future<void> _onEditRequested(
    ScheduleFormEditRequested event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(
      status: ScheduleFormStatus.loading,
    ));

    final PreparationEntity preparationEntity =
        await _getPreparationByScheduleIdUseCase(event.schedule.id);

    emit(state.copyWith(
      status: ScheduleFormStatus.success,
      id: event.schedule.id,
      placeName: event.schedule.place.placeName,
      scheduleName: event.schedule.scheduleName,
      scheduleTime: event.schedule.scheduleTime,
      moveTime: event.schedule.moveTime,
      isChanged: event.schedule.isChanged,
      scheduleSpareTime: event.schedule.scheduleSpareTime,
      scheduleNote: event.schedule.scheduleNote,
      spareTime: event.schedule.scheduleSpareTime,
      preparation: preparationEntity,
    ));
  }

  void _onCreateRequested(
    ScheduleFormCreateRequested event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(
      status: ScheduleFormStatus.loading,
    ));

    final PreparationEntity defaultPreparationStepList =
        await _getDefaultPreparationUseCase();

    emit(state.copyWith(
      status: ScheduleFormStatus.success,
      id: Uuid().v7(),
      placeName: null,
      scheduleName: null,
      scheduleTime: null,
      moveTime: null,
      isChanged: null,
      scheduleSpareTime: null,
      scheduleNote: null,
      spareTime: null,
      preparation: defaultPreparationStepList,
    ));
  }

  void _onScheduleNameChanged(
    ScheduleFormScheduleNameChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(scheduleName: event.scheduleName));
  }

  void _onScheduleDateChanged(
    ScheduleFormScheduleDateChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(
        scheduleTime: state.scheduleTime?.copyWith(
              year: event.scheduleDate.year,
              month: event.scheduleDate.month,
              day: event.scheduleDate.day,
            ) ??
            event.scheduleDate));
  }

  void _onScheduleTimeChanged(
    ScheduleFormScheduleTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(
        scheduleTime: state.scheduleTime?.copyWith(
              hour: event.scheduleTime.hour,
              minute: event.scheduleTime.minute,
            ) ??
            event.scheduleTime));
  }

  void _onPlaceNameChanged(
    ScheduleFormPlaceNameChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(placeName: event.placeName));
  }

  void _onMoveTimeChanged(
    ScheduleFormMoveTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(moveTime: event.moveTime));
  }

  void _onScheduleSpareTimeChanged(
    ScheduleFormScheduleSpareTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(scheduleSpareTime: event.scheduleSpareTime));
  }

  void _onPreparationChanged(
    ScheduleFormPreparationChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(preparation: event.preparation));
  }

  void _onSaved(
    ScheduleFormSaved event,
    Emitter<ScheduleFormState> emit,
  ) {}

  Future<void> _getUserDefaultPreparation() {
    throw UnimplementedError();
  }
}
