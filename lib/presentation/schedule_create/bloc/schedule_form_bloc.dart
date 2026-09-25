import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/repositories/schedule_aggregate_repository.dart';
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
import 'package:collection/collection.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'schedule_time_save_review.dart';

part 'schedule_form_event.dart';
part 'schedule_form_state.dart';

// Transient approval over a frozen projection; never serialized or used as a
// second writer. The review object itself is the UI's exact instance key.
class _RecurrenceReviewAuthority {
  const _RecurrenceReviewAuthority({
    required this.review,
    required this.submission,
    required this.owner,
    required this.revision,
    required this.editing,
  });
  final RecurrenceReview review;
  final ScheduleFormSubmission submission;
  final Object owner;
  final int revision;
  final bool editing;
}

class _AcceptedRecurrenceReview {
  const _AcceptedRecurrenceReview(this.authority, this.submission);
  final _RecurrenceReviewAuthority authority;
  final ScheduleFormSubmission submission;
}

@Injectable()
class ScheduleFormBloc extends Bloc<ScheduleFormEvent, ScheduleFormState> {
  ScheduleFormBloc(
    this._loadScheduleFormDraftUseCase,
    this._createScheduleFormSubmissionUseCase,
    this._updateScheduleFormSubmissionUseCase, {
    RecurringSchedulesUseCase? recurringSchedules,
    ScheduleAggregateRepository? aggregate,
    @ignoreParam DateTime Function()? now,
  }) : _aggregate = aggregate,
       _now = now ?? DateTime.now,
       _recurring = recurringSchedules,
       super(ScheduleFormState()) {
    on<ScheduleFormBaselineAccepted>((event, emit) {
      if (!_owns(event.owner) || _saving) return;
      emit(
        state.copyWith(
          baseline: event.baseline,
          mutationId: const Uuid().v7(),
          originalSchedule: event.current,
          saveFailure: null,
          submissionStatus: ScheduleFormSubmissionStatus.idle,
        ),
      );
    });
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
    on<ScheduleFormTimeReviewConfirmed>(_onTimeReviewConfirmed);
    on<ScheduleFormRecurrenceReviewConfirmed>(_onRecurrenceReviewConfirmed);
    on<ScheduleFormValidated>(_onValidated);
    on<ScheduleFormRecurringChanged>(
      (event, emit) => _saving
          ? null
          : emit(
              state.copyWith(
                recurrenceRule: event.rule,
                recurrenceCountChanged:
                    state.recurrenceCountChanged || event.countChanged,
                submissionStatus: ScheduleFormSubmissionStatus.idle,
                recurrenceReview: null,
              ),
            ),
    );
    on<ScheduleFormReviewDismissed>((event, emit) {
      if (_saving) return;
      _pendingTimeReview = null;
      _pendingRecurrenceReview = null;
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.idle,
          timeReview: null,
        ),
      );
    });
    on<ScheduleFormRepeatedTimeChosen>((event, emit) async {
      if (_saving) return;
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
  final ScheduleAggregateRepository? _aggregate;
  final DateTime Function() _now;
  int _draftRevision = 0;
  ScheduleTimeSaveReview? _pendingTimeReview;
  ScheduleTimeSaveReview? _acceptedTimeReview;
  _RecurrenceReviewAuthority? _pendingRecurrenceReview;
  _AcceptedRecurrenceReview? _acceptedRecurrenceReview;

  List<Object?> _reviewInputs(ScheduleFormState value) => [
    value.baseline,
    value.mutationId,
    value.id,
    value.placeId,
    value.placeName,
    value.scheduleName,
    value.scheduleTime,
    value.timeZoneId,
    value.occurrenceOffsetSeconds,
    value.moveTime,
    value.scheduleSpareTime,
    value.scheduleNote,
    value.preparation,
    value.originalSchedule,
    value.originalPreparation,
    value.isChanged,
    value.recurrenceRule,
    value.recurringScope,
    value.recurrenceCountChanged,
  ];

  @override
  void onChange(Change<ScheduleFormState> change) {
    if (!const DeepCollectionEquality().equals(
      _reviewInputs(change.currentState),
      _reviewInputs(change.nextState),
    )) {
      _draftRevision++;
      _pendingTimeReview = null;
      _acceptedTimeReview = null;
      _pendingRecurrenceReview = null;
      _acceptedRecurrenceReview = null;
    }
    super.onChange(change);
  }

  bool _ownsRecurrenceAuthority(_RecurrenceReviewAuthority authority) =>
      !isClosed &&
      _owns(authority.owner) &&
      _draftRevision == authority.revision &&
      state.mutationId == authority.submission.mutationId &&
      state.baseline == authority.submission.baseline;

  bool ownsRecurrenceReview(RecurrenceReview review) {
    final pending = _pendingRecurrenceReview;
    return pending != null &&
        identical(pending.review, review) &&
        _ownsRecurrenceAuthority(pending);
  }

  ScheduleFormSubmission _freezeRecurrenceSubmission(
    ScheduleFormSubmission value, {
    Set<String> excludedSlots = const {},
    String? firstSlot,
    bool confirmed = false,
  }) => ScheduleFormSubmission(
    mutationId: value.mutationId,
    baseline: value.baseline,
    schedule: value.schedule,
    preparation: PreparationEntity(
      preparationStepList: List.unmodifiable(
        value.preparation.preparationStepList,
      ),
    ),
    preparationChanged: value.preparationChanged,
    originalPreparationMode: value.originalPreparationMode,
    originalSchedule: value.originalSchedule,
    recurrenceRule: value.recurrenceRule,
    recurringScope: value.recurringScope,
    recurrenceCountChanged: value.recurrenceCountChanged,
    excludedSlots: Set.unmodifiable(excludedSlots),
    confirmDetached: confirmed,
    reviewedFirstSlotKey: firstSlot,
  );

  void _issueRecurrenceReview(
    Emitter<ScheduleFormState> emit,
    RecurrenceReview result,
    ScheduleFormSubmission submission, {
    required Object owner,
    required bool editing,
  }) {
    if (!_owns(owner) || isClosed) return;
    final review = RecurrenceReview(
      slots: List.unmodifiable(result.slots),
      skipped: List.unmodifiable(result.skipped),
      conflicts: List.unmodifiable(result.conflicts),
      detached: List.unmodifiable(result.detached),
      persistentConflict: result.persistentConflict,
      occurrences: Map.unmodifiable(result.occurrences),
      totalOccurrences: result.totalOccurrences,
    );
    _acceptedRecurrenceReview = null;
    _pendingRecurrenceReview = _RecurrenceReviewAuthority(
      review: review,
      submission: _freezeRecurrenceSubmission(submission),
      owner: owner,
      revision: _draftRevision,
      editing: editing,
    );
    emit(
      state.copyWith(
        submissionStatus: ScheduleFormSubmissionStatus.review,
        recurrenceReview: review,
      ),
    );
  }

  Future<void> _onRecurrenceReviewConfirmed(
    ScheduleFormRecurrenceReviewConfirmed event,
    Emitter<ScheduleFormState> emit,
  ) async {
    if (_saving) return;
    final replay = _acceptedRecurrenceReview;
    if (replay != null &&
        identical(replay.authority.review, event.review) &&
        _ownsRecurrenceAuthority(replay.authority) &&
        const SetEquality<String>().equals(
          replay.submission.excludedSlots,
          event.excludedSlots,
        )) {
      await _submit(
        emit,
        editing: replay.authority.editing,
        recurrenceSubmission: replay.submission,
      );
      return;
    }
    final pending = _pendingRecurrenceReview;
    if (pending == null || !ownsRecurrenceReview(event.review)) return;
    final keys = pending.review.slots.map((slot) => slot.key).toSet();
    if (pending.review.persistentConflict ||
        !keys.containsAll(event.excludedSlots) ||
        keys.difference(event.excludedSlots).isEmpty) {
      return;
    }
    final submission = _freezeRecurrenceSubmission(
      pending.submission,
      excludedSlots: event.excludedSlots,
      confirmed: true,
      firstSlot: pending.review.slots
          .firstWhere((slot) => !event.excludedSlots.contains(slot.key))
          .key,
    );
    _pendingRecurrenceReview = null;
    _acceptedRecurrenceReview = _AcceptedRecurrenceReview(pending, submission);
    await _submit(
      emit,
      editing: pending.editing,
      recurrenceSubmission: submission,
    );
  }

  bool _needsTimeReview(ScheduleEntity proposed) {
    final original = state.originalSchedule;
    return original == null ||
        CivilDateTime.fromFields(original.scheduleTime) !=
            CivilDateTime.fromFields(proposed.scheduleTime) ||
        original.timeZoneId != proposed.timeZoneId ||
        original.occurrenceOffsetSeconds != proposed.occurrenceOffsetSeconds;
  }

  bool _ownsTimeReview(ScheduleTimeSaveReview review) =>
      identical(_pendingTimeReview, review) &&
      _owns(review.formOwner) &&
      _draftRevision == review.draftRevision &&
      state.baseline == review.baseline;

  void _validateAcceptedTimeReview(ScheduleTimeSaveReview review) {
    if (!identical(_acceptedTimeReview, review) ||
        !_owns(review.formOwner) ||
        _draftRevision != review.draftRevision ||
        state.baseline != review.baseline) {
      throw const ScheduleSaveRejected(ScheduleSaveFailure.conflict);
    }
    _validateReviewTime(review);
  }

  void _validateReviewTime(ScheduleTimeSaveReview review) {
    final now = _now().toUtc();
    final current = ScheduleTimeResolver.resolve(review.proposed, nowUtc: now);
    final crossedPreparation =
        review.preparationStartUtc.isAfter(review.reviewedAtUtc) &&
        !review.preparationStartUtc.isAfter(now);
    if (now.isBefore(review.reviewedAtUtc) ||
        crossedPreparation ||
        TimeZoneRules.loadedIdentity != review.rulesIdentity ||
        current.status != ScheduleTimeResolutionStatus.resolved ||
        current.instantUtc != review.resolution.instantUtc ||
        !review.resolution.instantUtc!.isAfter(now)) {
      throw const ScheduleSaveRejected(ScheduleSaveFailure.conflict);
    }
  }

  Future<void> _onTimeReviewConfirmed(
    ScheduleFormTimeReviewConfirmed event,
    Emitter<ScheduleFormState> emit,
  ) async {
    final review = event.review;
    if (_saving || !_ownsTimeReview(review)) return;
    try {
      if (_aggregate != null) {
        final current = await _aggregate.newBaseline();
        if (!_ownsTimeReview(review)) return;
        final old = review.baseline;
        if (old == null ||
            old.store != current.store ||
            old.generation != current.generation ||
            old.revision != current.revision) {
          throw const ScheduleSaveRejected(ScheduleSaveFailure.conflict);
        }
      }
      _validateReviewTime(review);
      if (!_ownsTimeReview(review)) return;
      _pendingTimeReview = null;
      _acceptedTimeReview = review;
      await _submit(emit, editing: review.editing, timeReviewed: true);
    } on ScheduleSaveRejected catch (error) {
      if (!_ownsTimeReview(review)) return;
      _pendingTimeReview = null;
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.failure,
          saveFailure: error.failure,
          timeReview: null,
        ),
      );
    } catch (_) {
      if (!_ownsTimeReview(review)) return;
      _pendingTimeReview = null;
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.failure,
          saveFailure: ScheduleSaveFailure.unavailable,
          timeReview: null,
        ),
      );
    }
  }

  Object _formOwner = Object();
  final _pendingOwners = <Object>{};
  Object get formOwner => _formOwner;
  bool ownsForm(Object owner) => _owns(owner);
  bool _owns(Object owner) => !isClosed && identical(owner, _formOwner);
  bool get _saving => _pendingOwners.contains(_formOwner);

  Future<
    ({
      Object owner,
      ScheduleEditBaseline baseline,
      ScheduleEditSnapshot? current,
    })
  >
  reviewCurrent() async {
    final owner = _formOwner;
    final current = state.originalSchedule == null
        ? null
        : await _aggregate!.readForEdit(state.id);
    final baseline = current?.baseline ?? await _aggregate!.newBaseline();
    if (!_owns(owner)) {
      throw const ScheduleSaveRejected(ScheduleSaveFailure.unavailable);
    }
    return (owner: owner, baseline: baseline, current: current);
  }

  void acceptReviewedBaseline(
    Object owner,
    ScheduleEditBaseline baseline,
    ScheduleEntity? current,
  ) {
    if (!_owns(owner) || _saving) return;
    add(ScheduleFormBaselineAccepted(owner, baseline, current));
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
    final owner = _formOwner = Object();
    emit(
      state.copyWith(
        status: ScheduleFormStatus.loading,
        submissionStatus: ScheduleFormSubmissionStatus.idle,
        submissionError: null,
      ),
    );

    final draft = await _loadScheduleFormDraftUseCase.edit(event.scheduleId);
    if (!_owns(owner)) return;
    final original = draft.originalSchedule;
    final following =
        (original?.isRecurring ?? false) &&
        event.scope == RecurringEditScope.following;
    _emitLoadedDraft(draft, emit, ready: !following);
    if (following) {
      final segment =
          draft.segment ??
          await _recurring!.getSegment(original!.recurringSegmentId!);
      if (!_owns(owner)) return;
      if (event.scope == RecurringEditScope.following) {
        final day = CivilDateTime.parse(
          original!.recurringSlotKey!,
        ).toUtcCarrier();
        final start = DateTime.utc(
          day.year,
          day.month,
          day.day,
          segment.rule.start.hour,
          segment.rule.start.minute,
          segment.rule.start.second,
          segment.rule.start.millisecond,
          segment.rule.start.microsecond,
        );
        final followingRule = segment.rule.withStartAndEnd(
          start: start,
          count: segment.rule.count,
          until: segment.rule.until,
        );
        int? selectedOffset;
        if (TimeZoneRules.contains(followingRule.timeZoneId)) {
          try {
            // Resolve exactly this original slot day under the base rule. A gap
            // must not borrow tomorrow's offset, and a fold uses its saved policy.
            final expansion = const RecurrenceEngine().expand(
              followingRule,
              through: start,
              limit: 1,
            );
            if (expansion.slots.isNotEmpty &&
                expansion.slots.first.civilTime == start) {
              selectedOffset = expansion.slots.first.offsetSeconds;
            }
          } on RepeatedTimeChoiceRequired {
            // Leave the draft unresolved for the existing explicit choice flow.
          }
        }
        emit(
          state.copyWith(
            status: ScheduleFormStatus.success,
            scheduleName: segment.schedule.scheduleName,
            placeId: segment.schedule.place.id,
            placeName: segment.schedule.place.placeName,
            scheduleTime: start,
            timeZoneId: segment.rule.timeZoneId,
            occurrenceOffsetSeconds: selectedOffset,
            moveTime: segment.schedule.moveTime,
            scheduleSpareTime: segment.schedule.scheduleSpareTime,
            scheduleNote: segment.schedule.scheduleNote,
            preparation: segment.preparation,
            originalPreparation: segment.preparation,
            recurringScope: event.scope,
            recurrenceRule: followingRule,
          ),
        );
      }
    }
  }

  void _onCreateRequested(
    ScheduleFormCreateRequested event,
    Emitter<ScheduleFormState> emit,
  ) async {
    final owner = _formOwner = Object();
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
    if (!_owns(owner)) return;
    _emitLoadedDraft(draft, emit);
  }

  void _onScheduleNameChanged(
    ScheduleFormScheduleNameChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    if (_saving) return;
    emit(state.copyWith(scheduleName: event.scheduleName));
  }

  void _onScheduleDateChanged(
    ScheduleFormScheduleDateTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    if (_saving) return;
    emit(
      state.copyWith(
        scheduleTime: DateTime.utc(
          event.scheduleDate.year,
          event.scheduleDate.month,
          event.scheduleDate.day,
          event.scheduleTime.hour,
          event.scheduleTime.minute,
          event.scheduleTime.second,
          event.scheduleTime.millisecond,
          event.scheduleTime.microsecond,
        ),
        occurrenceOffsetSeconds: event.occurrenceOffsetSeconds,
        timeZoneId: event.timeZoneId,
        timeZoneExplicitlySelected: event.timeZoneExplicitlySelected,
        recurrenceRule: event.timeZoneId == null
            ? state.recurrenceRule
            : state.recurrenceRule?.withTimeZone(event.timeZoneId!),
        maxAvailableTime: event.maxAvailableTime,
        previousScheduleName: event.previousScheduleName,
      ),
    );
  }

  void _onPlaceNameChanged(
    ScheduleFormPlaceNameChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    if (_saving) return;
    emit(state.copyWith(placeName: event.placeName));
  }

  void _onMoveTimeChanged(
    ScheduleFormMoveTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    if (_saving) return;
    emit(state.copyWith(moveTime: event.moveTime));
  }

  void _onScheduleSpareTimeChanged(
    ScheduleFormScheduleSpareTimeChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    if (_saving) return;
    emit(state.copyWith(scheduleSpareTime: event.scheduleSpareTime));
  }

  void _onPreparationChanged(
    ScheduleFormPreparationChanged event,
    Emitter<ScheduleFormState> emit,
  ) {
    if (_saving) return;
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
  ) => _submit(emit, editing: true);
  Future<void> _onCreated(
    ScheduleFormCreated event,
    Emitter<ScheduleFormState> emit,
  ) => _submit(emit, editing: false);

  Future<void> _submit(
    Emitter<ScheduleFormState> emit, {
    required bool editing,
    bool timeReviewed = false,
    ScheduleFormSubmission? recurrenceSubmission,
  }) async {
    if (_saving ||
        state.submissionStatus == ScheduleFormSubmissionStatus.submitting) {
      return;
    }
    final owner = _formOwner;
    _pendingOwners.add(owner);
    emit(
      state.copyWith(
        submissionStatus: ScheduleFormSubmissionStatus.submitting,
        submissionError: null,
      ),
    );
    ScheduleFormSubmission? submitted;
    try {
      final accepted = _acceptedRecurrenceReview;
      final replay =
          accepted != null &&
              accepted.authority.editing == editing &&
              _ownsRecurrenceAuthority(accepted.authority)
          ? accepted.submission
          : null;
      final value =
          recurrenceSubmission ??
          replay ??
          _submissionFor(state.createEntity(state));
      submitted = value;
      final recurrenceApproved = recurrenceSubmission != null || replay != null;
      if (value.recurrenceRule == null &&
          !timeReviewed &&
          _acceptedTimeReview == null &&
          state.saveReceipt?.deliveryPending != true &&
          _needsTimeReview(value.schedule)) {
        final now = _now().toUtc();
        final resolution = ScheduleTimeResolver.resolve(
          value.schedule,
          nowUtc: now,
        );
        if (resolution.status != ScheduleTimeResolutionStatus.resolved ||
            resolution.instantUtc == null ||
            !resolution.instantUtc!.isAfter(now)) {
          throw const ScheduleSaveRejected(ScheduleSaveFailure.invalid);
        }
        final review = ScheduleTimeSaveReview(
          original: state.originalSchedule,
          proposed: value.schedule,
          resolution: resolution,
          baseline: state.baseline,
          reviewedAtUtc: now,
          preparationStartUtc: resolution.instantUtc!.subtract(
            state.totalPreparationTime +
                value.schedule.moveTime +
                (value.schedule.scheduleSpareTime ?? Duration.zero),
          ),
          rulesIdentity: TimeZoneRules.loadedIdentity,
          formOwner: owner,
          draftRevision: _draftRevision,
          editing: editing,
        );
        _pendingTimeReview = review;
        emit(
          state.copyWith(
            submissionStatus: ScheduleFormSubmissionStatus.timeReview,
            timeReview: review,
          ),
        );
        return;
      }
      if (value.recurrenceRule != null && !recurrenceApproved) {
        final frozen = _freezeRecurrenceSubmission(value);
        final review = await _recurring!.review(frozen);
        if (!_owns(owner)) return;
        if (review != null) {
          _issueRecurrenceReview(
            emit,
            review,
            frozen,
            owner: owner,
            editing: editing,
          );
          return;
        }
      }
      final receipt = state.saveReceipt?.deliveryPending == true
          ? await _createScheduleFormSubmissionUseCase.retryDelivery(
              state.saveReceipt!,
            )
          : editing
          ? await _updateScheduleFormSubmissionUseCase(value)
          : await _createScheduleFormSubmissionUseCase(value);
      if (!_owns(owner) ||
          (_aggregate != null && !_aggregate.isCurrent(receipt))) {
        return;
      }
      emit(
        state.copyWith(
          submissionStatus: receipt.deliveryPending
              ? ScheduleFormSubmissionStatus.deliveryPending
              : ScheduleFormSubmissionStatus.success,
          saveReceipt: receipt,
          submissionError: null,
        ),
      );
    } on ScheduleSaveRejected catch (e) {
      if (!_owns(owner)) return;
      // The writer rejected/rolled back this command. It needs fresh review.
      // Unclassified transport/response loss below retains the accepted intent
      // so the same mutation can replay its durable receipt without new data.
      _acceptedTimeReview = null;
      _acceptedRecurrenceReview = null;
      _pendingRecurrenceReview = null;
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.failure,
          saveFailure: e.failure,
        ),
      );
    } on RepeatedTimeChoiceRequired catch (e) {
      if (!_owns(owner)) return;
      _acceptedRecurrenceReview = null;
      _pendingRecurrenceReview = null;
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.timeChoice,
          repeatedTimeDate: e.civilTime,
        ),
      );
    } on RecurrenceNeedsReview catch (e) {
      if (!_owns(owner) || submitted == null) return;
      _issueRecurrenceReview(
        emit,
        e.review,
        submitted,
        owner: owner,
        editing: editing,
      );
    } catch (e) {
      if (!_owns(owner)) return;
      if (e is RecurrenceValidationException ||
          e is RecurrenceSearchLimit ||
          e is ArgumentError) {
        _acceptedRecurrenceReview = null;
        _pendingRecurrenceReview = null;
      }
      emit(
        state.copyWith(
          submissionStatus: ScheduleFormSubmissionStatus.failure,
          saveFailure:
              e is RecurrenceValidationException ||
                  e is RecurrenceSearchLimit ||
                  e is ArgumentError
              ? null
              : ScheduleSaveFailure.unavailable,
          submissionError: e is RecurrenceValidationException
              ? e.message
              : e is RecurrenceSearchLimit
              ? '반복 검사를 완료할 수 없어요. 종료 조건을 줄여 주세요.'
              : e is ArgumentError
              ? '반복 날짜와 종료 조건을 확인해 주세요.'
              : '저장하지 못했어요. 입력 내용은 유지되며 다시 시도할 수 있어요.',
        ),
      );
    } finally {
      _pendingOwners.remove(owner);
    }
  }

  void _onValidated(
    ScheduleFormValidated event,
    Emitter<ScheduleFormState> emit,
  ) {
    if (_saving) return;
    emit(state.copyWith(isValid: event.isValid));
  }

  void _emitLoadedDraft(
    ScheduleFormDraft draft,
    Emitter<ScheduleFormState> emit, {
    bool ready = true,
  }) {
    emit(
      ScheduleFormState(
        status: ready ? ScheduleFormStatus.success : ScheduleFormStatus.loading,
        submissionStatus: ScheduleFormSubmissionStatus.idle,
        submissionError: null,
        baseline: draft.baseline,
        mutationId: const Uuid().v7(),
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

  ScheduleFormSubmission _submissionFor(ScheduleEntity scheduleEntity) {
    final accepted = _acceptedTimeReview;
    return ScheduleFormSubmission(
      schedule: scheduleEntity,
      preparation: state.preparation!,
      baseline: state.baseline,
      mutationId: state.mutationId,
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
      validateTimeReview: accepted == null
          ? null
          : () => _validateAcceptedTimeReview(accepted),
      originalPreparationMode: state.originalPreparationMode,
    );
  }
}
