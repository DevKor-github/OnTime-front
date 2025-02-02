import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';
import 'package:uuid/uuid.dart';

part 'schedule_form_event.dart';
part 'schedule_form_state.dart';

@Injectable()
class ScheduleFormBloc extends Bloc<ScheduleFormEvent, ScheduleFormState> {
  ScheduleFormBloc(
    this._getPreparationByScheduleIdUseCase,
    this._getDefaultPreparationUseCase,
    this._getScheduleByIdUseCase,
    this._createScheduleWithPlaceUseCase,
    this._createCustomPreparationUseCase,
    this._updateScheduleUseCase,
    this._updatePreparationByScheduleIdUseCase,
  ) : super(ScheduleFormState()) {
    on<ScheduleFormEditRequested>(_onEditRequested);
    on<ScheduleFormCreateRequested>(_onCreateRequested);
    on<ScheduleFormScheduleNameChanged>(_onScheduleNameChanged);
    on<ScheduleFormScheduleDateChanged>(_onScheduleDateChanged);
    on<ScheduleFormScheduleTimeChanged>(_onScheduleTimeChanged);
    on<ScheduleFormPlaceNameChanged>(_onPlaceNameChanged);
    on<ScheduleFormMoveTimeChanged>(_onMoveTimeChanged);
    on<ScheduleFormScheduleSpareTimeChanged>(_onScheduleSpareTimeChanged);
    on<ScheduleFormPreparationChanged>(_onPreparationChanged);
    on<ScheduleFormUpdated>(_onUpdated);
    on<ScheduleFormSaved>(_onSaved);
  }

  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final GetDefaultPreparationUseCase _getDefaultPreparationUseCase;
  final GetScheduleByIdUseCase _getScheduleByIdUseCase;
  final CreateScheduleWithPlaceUseCase _createScheduleWithPlaceUseCase;
  final CreateCustomPreparationUseCase _createCustomPreparationUseCase;
  final UpdateScheduleUseCase _updateScheduleUseCase;
  final UpdatePreparationByScheduleIdUseCase
      _updatePreparationByScheduleIdUseCase;

  Future<void> _onEditRequested(
    ScheduleFormEditRequested event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(state.copyWith(
      status: ScheduleFormStatus.loading,
    ));

    final PreparationEntity preparationEntity =
        await _getPreparationByScheduleIdUseCase(event.scheduleId);

    final ScheduleEntity scheduleEntity =
        await _getScheduleByIdUseCase(event.scheduleId);

    emit(state.copyWith(
      status: ScheduleFormStatus.success,
      id: scheduleEntity.id,
      placeName: scheduleEntity.place.placeName,
      scheduleName: scheduleEntity.scheduleName,
      scheduleTime: scheduleEntity.scheduleTime,
      moveTime: scheduleEntity.moveTime,
      isChanged: scheduleEntity.isChanged
          ? IsPreparationChanged.changed
          : IsPreparationChanged.unchanged,
      scheduleSpareTime: scheduleEntity.scheduleSpareTime,
      scheduleNote: scheduleEntity.scheduleNote,
      spareTime: scheduleEntity.scheduleSpareTime,
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
    final IsPreparationChanged isChagned;
    if (state.isChanged == IsPreparationChanged.changed) {
      // already changed
      isChagned = IsPreparationChanged.changed;
    } else if (state.preparation == event.preparation) {
      // not changed
      isChagned = IsPreparationChanged.unchanged;
    }
    // else if (isOnlyOrderChanged(state.preparation, event.preparation)) {
    //   // only order changed
    //   isChagned = IsPreparationChanged.orderChanged;
    // }
    else {
      // changed
      isChagned = IsPreparationChanged.changed;
    }

    emit(state.copyWith(
      preparation: event.preparation,
      isChanged: isChagned,
    ));
  }

  bool _isOnlyOrderChanged(PreparationEntity? a, PreparationEntity? b) {
    if (a == null && b == null) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    final A = a.preparationStepList
        .map((e) => e.copyWith(nextPreparationId: ''))
        .toSet();
    final B = b.preparationStepList
        .map((e) => e.copyWith(nextPreparationId: ''))
        .toSet();
    return setEquals<PreparationStepEntity>(A, B);
  }

  Future<void> _onUpdated(
    ScheduleFormUpdated event,
    Emitter<ScheduleFormState> emit,
  ) async {
    final ScheduleEntity scheduleEntity = state.createEntity(state);
    await _updateScheduleUseCase(scheduleEntity);
    if (state.isChanged != IsPreparationChanged.unchanged) {
      _updatePreparationByScheduleIdUseCase(
          state.preparation!, scheduleEntity.id);
    }
  }

  Future<void> _onSaved(
    ScheduleFormSaved event,
    Emitter<ScheduleFormState> emit,
  ) async {
    final ScheduleEntity scheduleEntity = state.createEntity(state);
    await _createScheduleWithPlaceUseCase(scheduleEntity);
    if (state.isChanged != IsPreparationChanged.unchanged) {
      await _createCustomPreparationUseCase(
          state.preparation!, scheduleEntity.id);
    }
  }
}
