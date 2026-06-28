import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/dio/api_error_message.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/entities/product_usage_event.dart';
import 'package:on_time_front/domain/use-cases/track_product_usage_event_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:uuid/uuid.dart';

part 'schedule_form_event.dart';
part 'schedule_form_state.dart';

@Injectable()
class ScheduleFormBloc extends Bloc<ScheduleFormEvent, ScheduleFormState> {
  ScheduleFormBloc(
    this._loadPreparationByScheduleIdUseCase,
    this._getPreparationByScheduleIdUseCase,
    this._getDefaultPreparationUseCase,
    this._getScheduleByIdUseCase,
    this._createScheduleWithPlaceUseCase,
    this._createCustomPreparationUseCase,
    this._updateScheduleUseCase,
    this._updatePreparationByScheduleIdUseCase,
    this._productUsageEventTracker,
    @factoryParam this._authBloc,
  ) : super(ScheduleFormState()) {
    on<ScheduleFormEditRequested>(_onEditRequested);
    on<ScheduleFormCreateRequested>(_onCreateRequested);
    on<ScheduleFormScheduleNameChanged>(_onScheduleNameChanged);
    on<ScheduleFormScheduleDateTimeChanged>(_onScheduleDateChanged);
    on<ScheduleFormPlaceNameChanged>(_onPlaceNameChanged);
    on<ScheduleFormMoveTimeChanged>(_onMoveTimeChanged);
    on<ScheduleFormScheduleSpareTimeChanged>(_onScheduleSpareTimeChanged);
    on<ScheduleFormPreparationChanged>(_onPreparationChanged);
    on<ScheduleFormUpdated>(_onUpdated);
    on<ScheduleFormCreated>(_onCreated);
    on<ScheduleFormValidated>(_onValidated);
  }

  final LoadPreparationByScheduleIdUseCase _loadPreparationByScheduleIdUseCase;
  final GetPreparationByScheduleIdUseCase _getPreparationByScheduleIdUseCase;
  final GetDefaultPreparationUseCase _getDefaultPreparationUseCase;
  final GetScheduleByIdUseCase _getScheduleByIdUseCase;
  final CreateScheduleWithPlaceUseCase _createScheduleWithPlaceUseCase;
  final CreateCustomPreparationUseCase _createCustomPreparationUseCase;
  final UpdateScheduleUseCase _updateScheduleUseCase;
  final UpdatePreparationByScheduleIdUseCase
  _updatePreparationByScheduleIdUseCase;
  final ProductUsageEventTracker _productUsageEventTracker;
  final AuthBloc _authBloc;

  Future<void> _onEditRequested(
    ScheduleFormEditRequested event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ScheduleFormStatus.loading,
        submissionStatus: ScheduleFormSubmissionStatus.idle,
        submissionError: null,
      ),
    );

    await _loadPreparationByScheduleIdUseCase(event.scheduleId);
    final PreparationEntity preparationEntity =
        await _getPreparationByScheduleIdUseCase(event.scheduleId);

    final ScheduleEntity scheduleEntity = await _getScheduleByIdUseCase(
      event.scheduleId,
    );

    emit(
      state.copyWith(
        status: ScheduleFormStatus.success,
        submissionStatus: ScheduleFormSubmissionStatus.idle,
        submissionError: null,
        id: scheduleEntity.id,
        placeId: scheduleEntity.place.id,
        placeName: scheduleEntity.place.placeName,
        scheduleName: scheduleEntity.scheduleName,
        scheduleTime: scheduleEntity.scheduleTime,
        moveTime: scheduleEntity.moveTime,
        isChanged: scheduleEntity.isChanged
            ? IsPreparationChanged.changed
            : IsPreparationChanged.unchanged,
        scheduleSpareTime: scheduleEntity.scheduleSpareTime,
        scheduleNote: scheduleEntity.scheduleNote,
        preparation: preparationEntity,
        originalPreparationMode: scheduleEntity.preparationMode,
      ),
    );
  }

  void _onCreateRequested(
    ScheduleFormCreateRequested event,
    Emitter<ScheduleFormState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ScheduleFormStatus.loading,
        submissionStatus: ScheduleFormSubmissionStatus.idle,
        submissionError: null,
      ),
    );

    final PreparationEntity defaultPreparationStepList =
        await _getDefaultPreparationUseCase();

    // Get spareTime from user model
    final userSpareTime = _authBloc.state.user.spareTimeOrNull;
    final now = DateTime.now();
    final initialScheduleTime = event.initialDate == null
        ? null
        : _initialScheduleTime(event.initialDate!, now);

    emit(
      state.copyWith(
        status: ScheduleFormStatus.success,
        submissionStatus: ScheduleFormSubmissionStatus.idle,
        submissionError: null,
        id: Uuid().v7(),
        placeId: Uuid().v7(),
        placeName: null,
        scheduleName: null,
        scheduleTime: initialScheduleTime,
        moveTime: null,
        isChanged: null,
        scheduleSpareTime: userSpareTime,
        scheduleNote: null,
        preparation: defaultPreparationStepList,
      ),
    );
  }

  void _onScheduleNameChanged(
    ScheduleFormScheduleNameChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(scheduleName: event.scheduleName));
  }

  void _onScheduleDateChanged(
    ScheduleFormScheduleDateTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(
      state.copyWith(
        scheduleTime: DateTime(
          event.scheduleDate.year,
          event.scheduleDate.month,
          event.scheduleDate.day,
          event.scheduleTime.hour,
          event.scheduleTime.minute,
        ),
        maxAvailableTime: event.maxAvailableTime,
        previousScheduleName: event.previousScheduleName,
      ),
    );
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
    if (state.preparation == event.preparation) {
      // not changed
      isChagned = IsPreparationChanged.unchanged;
    } else {
      isChagned = IsPreparationChanged.changed;
    }

    emit(state.copyWith(preparation: event.preparation, isChanged: isChagned));
  }

  Future<void> _onUpdated(
    ScheduleFormUpdated event,
    Emitter<ScheduleFormState> emit,
  ) async {
    if (state.submissionStatus == ScheduleFormSubmissionStatus.submitting) {
      return;
    }

    emit(
      state.copyWith(
        submissionStatus: ScheduleFormSubmissionStatus.submitting,
        submissionError: null,
      ),
    );

    try {
      final ScheduleEntity scheduleEntity = state.createEntity(state);
      await _updateScheduleUseCase(scheduleEntity);
      if (state.isChanged != IsPreparationChanged.unchanged) {
        await _updatePreparationByScheduleIdUseCase(
          _preparationForScheduleUpdate(),
          scheduleEntity.id,
        );
      }
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.success,
          submissionError: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.failure,
          submissionError: ApiErrorMessage.fromException(e) ?? e.toString(),
        ),
      );
    }
  }

  Future<void> _onCreated(
    ScheduleFormCreated event,
    Emitter<ScheduleFormState> emit,
  ) async {
    if (state.submissionStatus == ScheduleFormSubmissionStatus.submitting) {
      return;
    }

    emit(
      state.copyWith(
        submissionStatus: ScheduleFormSubmissionStatus.submitting,
        submissionError: null,
      ),
    );

    try {
      final ScheduleEntity scheduleEntity = state.createEntity(state);
      await _createScheduleWithPlaceUseCase(scheduleEntity);
      if (state.isChanged != IsPreparationChanged.unchanged) {
        await _createCustomPreparationUseCase(
          state.preparation!,
          scheduleEntity.id,
        );
      }
      await _trackScheduleCreated(scheduleEntity);
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.success,
          submissionError: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.failure,
          submissionError: ApiErrorMessage.fromException(e) ?? e.toString(),
        ),
      );
    }
  }

  void _onValidated(
    ScheduleFormValidated event,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(state.copyWith(isValid: event.isValid));
  }

  DateTime _initialScheduleTime(DateTime initialDate, DateTime now) {
    final selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final initialTime = selectedDate == today
        ? now.add(const Duration(minutes: 1))
        : now;
    return DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
      initialTime.hour,
      initialTime.minute,
    );
  }

  PreparationEntity _preparationForScheduleUpdate() {
    final preparation = state.preparation!;
    if (state.originalPreparationMode !=
        SchedulePreparationMode.defaultPreparation) {
      return preparation;
    }

    final orderedSteps = preparation.ordered.preparationStepList;
    final newIds = List.generate(orderedSteps.length, (_) => Uuid().v7());
    final copiedSteps = <PreparationStepEntity>[
      for (var i = 0; i < orderedSteps.length; i++)
        PreparationStepEntity(
          id: newIds[i],
          preparationName: orderedSteps[i].preparationName,
          preparationTime: orderedSteps[i].preparationTime,
          nextPreparationId: i + 1 < newIds.length ? newIds[i + 1] : null,
        ),
    ];

    return PreparationEntity(preparationStepList: copiedSteps);
  }

  Future<void> _trackScheduleCreated(ScheduleEntity scheduleEntity) async {
    await _productUsageEventTracker.track(
      ProductUsageEvent(
        name: 'schedule_created',
        workflow: 'schedule',
        result: 'success',
        parameters: {
          'preparation_mode': scheduleEntity.preparationMode?.name ?? 'default',
          'preparation_step_count':
              state.preparation?.preparationStepList.length ?? 0,
          'minutes_until_schedule': scheduleEntity.scheduleTime
              .difference(DateTime.now())
              .inMinutes,
        },
      ),
    );
  }
}
