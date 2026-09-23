import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
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
    this._updateScheduleFormSubmissionUseCase, {
    RecurringSchedulesUseCase? recurringSchedules,
  }) : _recurring = recurringSchedules,
       super(ScheduleFormState()) {
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
    on<ScheduleFormRecurringChanged>(
      (event, emit) => emit(
        state.copyWith(
          recurrenceRule: event.rule,
          recurrenceCountChanged:
              state.recurrenceCountChanged || event.countChanged,
          submissionStatus: ScheduleFormSubmissionStatus.idle,
          recurrenceReview: null,
        ),
      ),
    );
    on<ScheduleFormReviewDismissed>(
      (event, emit) => emit(
        state.copyWith(submissionStatus: ScheduleFormSubmissionStatus.idle),
      ),
    );
    on<ScheduleFormRepeatedTimeChosen>((event, emit) async {
      final rule = state.recurrenceRule!;
      emit(
        state.copyWith(
          recurrenceRule: rule.withStartAndEnd(
            count: rule.count,
            until: rule.until,
            repeatedTime: event.choice,
          ),
          submissionStatus: ScheduleFormSubmissionStatus.idle,
        ),
      );
      if (state.originalSchedule == null) {
        add(const ScheduleFormCreated());
      } else {
        add(const ScheduleFormUpdated());
      }
    });
  }

  final RecurringSchedulesUseCase? _recurring;
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
    final original = draft.originalSchedule;
    final following =
        (original?.isRecurring ?? false) &&
        event.scope == RecurringEditScope.following;
    _emitLoadedDraft(draft, emit, ready: !following);
    if (following) {
      final segment = await _recurring!.getSegment(
        original!.recurringSegmentId!,
      );
      if (event.scope == RecurringEditScope.following) {
        final day = DateTime.parse(original.recurringSlotKey!);
        final start = DateTime(
          day.year,
          day.month,
          day.day,
          segment.rule.start.hour,
          segment.rule.start.minute,
        );
        emit(
          state.copyWith(
            status: ScheduleFormStatus.success,
            scheduleName: segment.schedule.scheduleName,
            placeId: segment.schedule.place.id,
            placeName: segment.schedule.place.placeName,
            scheduleTime: start,
            moveTime: segment.schedule.moveTime,
            scheduleSpareTime: segment.schedule.scheduleSpareTime,
            scheduleNote: segment.schedule.scheduleNote,
            preparation: segment.preparation,
            originalPreparation: segment.preparation,
            recurringScope: event.scope,
            recurrenceRule: segment.rule.withStartAndEnd(
              start: start,
              count: segment.rule.count,
              until: segment.rule.until,
            ),
          ),
        );
      }
    }
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
        occurrenceOffsetSeconds: event.occurrenceOffsetSeconds,
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
  ) => _submit(
    emit,
    editing: true,
    confirmed: event.confirmed,
    excludedSlots: event.excludedSlots,
  );
  Future<void> _onCreated(
    ScheduleFormCreated event,
    Emitter<ScheduleFormState> emit,
  ) => _submit(
    emit,
    editing: false,
    confirmed: event.confirmed,
    excludedSlots: event.excludedSlots,
  );

  Future<void> _submit(
    Emitter<ScheduleFormState> emit, {
    required bool editing,
    required bool confirmed,
    required Set<String> excludedSlots,
  }) async {
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
      final value = _submissionFor(
        state.createEntity(state),
        confirmed: confirmed,
        excludedSlots: excludedSlots,
      );
      if (value.recurrenceRule != null && !confirmed) {
        final review = await _recurring!.review(value);
        if (review != null) {
          emit(
            state.copyWith(
              submissionStatus: ScheduleFormSubmissionStatus.review,
              recurrenceReview: review,
            ),
          );
          return;
        }
      }
      if (editing) {
        await _updateScheduleFormSubmissionUseCase(value);
      } else {
        await _createScheduleFormSubmissionUseCase(value);
      }
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.success,
          submissionError: null,
        ),
      );
    } on RepeatedTimeChoiceRequired catch (e) {
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.timeChoice,
          repeatedTimeDate: e.civilTime,
        ),
      );
    } on RecurrenceNeedsReview catch (e) {
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.review,
          recurrenceReview: e.review,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.failure,
          submissionError: e is RecurrenceValidationException
              ? e.message
              : e is RecurrenceSearchLimit
              ? '반복 검사를 완료할 수 없어요. 종료 조건을 줄여 주세요.'
              : e is ArgumentError
              ? '반복 날짜와 종료 조건을 확인해 주세요.'
              : '저장하지 못했어요. 입력 내용은 유지되며 다시 시도할 수 있어요.',
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
    Emitter<ScheduleFormState> emit, {
    bool ready = true,
  }) {
    emit(
      state.copyWith(
        status: ready ? ScheduleFormStatus.success : ScheduleFormStatus.loading,
        submissionStatus: ScheduleFormSubmissionStatus.idle,
        submissionError: null,
        id: draft.id,
        placeId: draft.placeId,
        placeName: draft.placeName,
        scheduleName: draft.scheduleName,
        scheduleTime: draft.scheduleTime,
        timeZoneId: draft.timeZoneId,
        occurrenceOffsetSeconds: draft.occurrenceOffsetSeconds,
        moveTime: draft.moveTime,
        isChanged: draft.preparationChanged
            ? IsPreparationChanged.changed
            : IsPreparationChanged.unchanged,
        scheduleSpareTime: draft.scheduleSpareTime,
        scheduleNote: draft.scheduleNote,
        preparation: draft.preparation,
        originalPreparationMode: draft.originalPreparationMode,
        originalSchedule: draft.originalSchedule,
        originalPreparation: draft.preparation,
      ),
    );
  }

  ScheduleFormSubmission _submissionFor(
    ScheduleEntity scheduleEntity, {
    bool confirmed = false,
    Set<String> excludedSlots = const {},
  }) {
    return ScheduleFormSubmission(
      schedule: scheduleEntity,
      preparation: state.preparation!,
      preparationChanged:
          state.originalSchedule?.preparationDefinitionId != null
          ? state.preparation != state.originalPreparation
          : state.isChanged != IsPreparationChanged.unchanged,
      originalSchedule: state.originalSchedule,
      recurrenceRule: state.recurrenceRule?.withStartAndEnd(
        start: state.scheduleTime,
        count: state.recurrenceRule?.count,
        until: state.recurrenceRule?.until,
      ),
      recurringScope: state.recurringScope,
      recurrenceCountChanged: state.recurrenceCountChanged,
      excludedSlots: excludedSlots,
      confirmDetached: confirmed,
      reviewedFirstSlotKey: confirmed
          ? state.recurrenceReview?.slots
                .where((s) => !excludedSlots.contains(s.key))
                .firstOrNull
                ?.key
          : null,
      originalPreparationMode: state.originalPreparationMode,
    );
  }
}
