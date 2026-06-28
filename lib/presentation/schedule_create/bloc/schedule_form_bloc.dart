import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/dio/api_error_message.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedule_form_draft_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_form_submission_use_case.dart';
import 'package:uuid/uuid.dart';

part 'schedule_form_event.dart';
part 'schedule_form_state.dart';

@Injectable()
class ScheduleFormBloc extends Bloc<ScheduleFormEvent, ScheduleFormState> {
  ScheduleFormBloc(
    this._loadScheduleFormDraftUseCase,
    this._createScheduleFormSubmissionUseCase,
    this._updateScheduleFormSubmissionUseCase,
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

  final LoadScheduleFormDraftUseCase _loadScheduleFormDraftUseCase;
  final CreateScheduleFormSubmissionUseCase
  _createScheduleFormSubmissionUseCase;
  final UpdateScheduleFormSubmissionUseCase
  _updateScheduleFormSubmissionUseCase;

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

    final draft = await _loadScheduleFormDraftUseCase.edit(event.scheduleId);
    _emitLoadedDraft(draft, emit);
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

    final draft = await _loadScheduleFormDraftUseCase.create(
      initialDate: event.initialDate,
      currentUserSpareTime: event.currentUserSpareTime,
    );
    _emitLoadedDraft(draft, emit);
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
      await _updateScheduleFormSubmissionUseCase(
        _submissionFor(scheduleEntity),
      );
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
      await _createScheduleFormSubmissionUseCase(
        _submissionFor(scheduleEntity),
      );
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

  void _emitLoadedDraft(
    ScheduleFormDraft draft,
    Emitter<ScheduleFormState> emit,
  ) {
    emit(
      state.copyWith(
        status: ScheduleFormStatus.success,
        submissionStatus: ScheduleFormSubmissionStatus.idle,
        submissionError: null,
        id: draft.id,
        placeId: draft.placeId,
        placeName: draft.placeName,
        scheduleName: draft.scheduleName,
        scheduleTime: draft.scheduleTime,
        moveTime: draft.moveTime,
        isChanged: draft.preparationChanged
            ? IsPreparationChanged.changed
            : IsPreparationChanged.unchanged,
        scheduleSpareTime: draft.scheduleSpareTime,
        scheduleNote: draft.scheduleNote,
        preparation: draft.preparation,
        originalPreparationMode: draft.originalPreparationMode,
      ),
    );
  }

  ScheduleFormSubmission _submissionFor(ScheduleEntity scheduleEntity) {
    return ScheduleFormSubmission(
      schedule: scheduleEntity,
      preparation: state.preparation!,
      preparationChanged: state.isChanged != IsPreparationChanged.unchanged,
      originalPreparationMode: state.originalPreparationMode,
    );
  }
}
