import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_form_submission_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedule_form_draft_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_form_submission_use_case.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';

const _unset = Object();

class StubLoadScheduleFormDraftUseCase implements LoadScheduleFormDraftUseCase {
  StubLoadScheduleFormDraftUseCase({
    required this.createHandler,
    required this.editHandler,
  });

  Future<ScheduleFormDraft> Function({
    DateTime? initialDate,
    Duration? currentUserSpareTime,
  })
  createHandler;
  Future<ScheduleFormDraft> Function(String scheduleId) editHandler;

  @override
  Future<ScheduleFormDraft> create({
    DateTime? initialDate,
    Duration? currentUserSpareTime,
  }) {
    return createHandler(
      initialDate: initialDate,
      currentUserSpareTime: currentUserSpareTime,
    );
  }

  @override
  Future<ScheduleFormDraft> edit(String scheduleId) => editHandler(scheduleId);
}

class SpyCreateScheduleFormSubmissionUseCase
    implements CreateScheduleFormSubmissionUseCase {
  Future<void> Function(ScheduleFormSubmission submission)? handler;
  final submissions = <ScheduleFormSubmission>[];

  @override
  Future<void> call(ScheduleFormSubmission submission) async {
    submissions.add(submission);
    await handler?.call(submission);
  }
}

class SpyUpdateScheduleFormSubmissionUseCase
    implements UpdateScheduleFormSubmissionUseCase {
  Future<void> Function(ScheduleFormSubmission submission)? handler;
  final submissions = <ScheduleFormSubmission>[];

  @override
  Future<void> call(ScheduleFormSubmission submission) async {
    submissions.add(submission);
    await handler?.call(submission);
  }
}

void main() {
  late StubLoadScheduleFormDraftUseCase loadScheduleFormDraftUseCase;
  late SpyCreateScheduleFormSubmissionUseCase
  createScheduleFormSubmissionUseCase;
  late SpyUpdateScheduleFormSubmissionUseCase
  updateScheduleFormSubmissionUseCase;

  final preparation = PreparationEntity(
    preparationStepList: const [
      PreparationStepEntity(
        id: 'prep-1',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 10),
      ),
    ],
  );

  final schedule = ScheduleEntity(
    id: 'schedule-1',
    place: PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Meeting',
    scheduleTime: DateTime(2027, 3, 20, 9, 0),
    moveTime: const Duration(minutes: 30),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 10),
    scheduleNote: 'bring laptop',
  );

  ScheduleFormDraft draftFromSchedule({
    bool preparationChanged = false,
    Duration? spareTime = const Duration(minutes: 10),
    Object? scheduleTime = _unset,
    SchedulePreparationMode? originalPreparationMode,
  }) {
    return ScheduleFormDraft(
      id: schedule.id,
      placeId: schedule.place.id,
      placeName: schedule.place.placeName,
      scheduleName: schedule.scheduleName,
      scheduleTime: identical(scheduleTime, _unset)
          ? schedule.scheduleTime
          : scheduleTime as DateTime?,
      moveTime: schedule.moveTime,
      preparationChanged: preparationChanged,
      scheduleSpareTime: spareTime,
      scheduleNote: schedule.scheduleNote,
      preparation: preparation,
      originalPreparationMode: originalPreparationMode,
    );
  }

  ScheduleFormBloc buildBloc() {
    return ScheduleFormBloc(
      loadScheduleFormDraftUseCase,
      createScheduleFormSubmissionUseCase,
      updateScheduleFormSubmissionUseCase,
    );
  }

  Future<void> primeEditState(ScheduleFormBloc bloc) async {
    final editReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
    await editReady;
  }

  Future<void> primeCreateState(ScheduleFormBloc bloc) async {
    final createReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(
      const ScheduleFormCreateRequested(
        currentUserSpareTime: Duration(minutes: 5),
      ),
    );
    await createReady;
  }

  setUp(() {
    loadScheduleFormDraftUseCase = StubLoadScheduleFormDraftUseCase(
      createHandler:
          ({DateTime? initialDate, Duration? currentUserSpareTime}) async {
            return draftFromSchedule(
              spareTime: currentUserSpareTime,
              scheduleTime: initialDate,
            );
          },
      editHandler: (_) async => draftFromSchedule(),
    );
    createScheduleFormSubmissionUseCase =
        SpyCreateScheduleFormSubmissionUseCase();
    updateScheduleFormSubmissionUseCase =
        SpyUpdateScheduleFormSubmissionUseCase();
  });

  test('ScheduleFormCreateRequested maps loaded draft into state', () async {
    DateTime? requestedInitialDate;
    Duration? requestedSpareTime;
    loadScheduleFormDraftUseCase.createHandler =
        ({DateTime? initialDate, Duration? currentUserSpareTime}) async {
          requestedInitialDate = initialDate;
          requestedSpareTime = currentUserSpareTime;
          return draftFromSchedule(
            spareTime: currentUserSpareTime,
            scheduleTime: initialDate,
          );
        };
    final bloc = buildBloc();
    addTearDown(bloc.close);

    final createReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(
      ScheduleFormCreateRequested(
        initialDate: DateTime(2027, 4, 5),
        currentUserSpareTime: const Duration(minutes: 5),
      ),
    );
    final state = await createReady;

    expect(requestedInitialDate, DateTime(2027, 4, 5));
    expect(requestedSpareTime, const Duration(minutes: 5));
    expect(state.scheduleTime, DateTime(2027, 4, 5));
    expect(state.scheduleSpareTime, const Duration(minutes: 5));
    expect(state.preparation, preparation);
  });

  test(
    'ScheduleFormEditRequested maps changed preparation flag into state',
    () async {
      loadScheduleFormDraftUseCase.editHandler = (_) async =>
          draftFromSchedule(preparationChanged: true);
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await primeEditState(bloc);

      expect(bloc.state.id, 'schedule-1');
      expect(bloc.state.placeName, 'Office');
      expect(bloc.state.isChanged, IsPreparationChanged.changed);
      expect(bloc.state.preparation, preparation);
    },
  );

  test(
    'ScheduleFormEditRequested keeps original preparation mode in state',
    () async {
      loadScheduleFormDraftUseCase.editHandler = (_) async => draftFromSchedule(
        originalPreparationMode: SchedulePreparationMode.defaultPreparation,
      );
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await primeEditState(bloc);

      expect(
        bloc.state.originalPreparationMode,
        SchedulePreparationMode.defaultPreparation,
      );
    },
  );

  test(
    'ScheduleFormUpdated sends edited schedule fields to submission use case',
    () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await primeEditState(bloc);

      bloc.add(
        const ScheduleFormScheduleNameChanged(scheduleName: 'Edited Meeting'),
      );
      bloc.add(
        ScheduleFormScheduleDateTimeChanged(
          scheduleDate: DateTime(2027, 3, 21),
          scheduleTime: DateTime(2027, 3, 21, 10, 30),
        ),
      );
      bloc.add(const ScheduleFormPlaceNameChanged(placeName: 'New Office'));
      bloc.add(
        const ScheduleFormMoveTimeChanged(moveTime: Duration(minutes: 45)),
      );
      bloc.add(
        const ScheduleFormScheduleSpareTimeChanged(
          scheduleSpareTime: Duration(minutes: 25),
        ),
      );

      final submitDone = bloc.stream.firstWhere(
        (state) =>
            state.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      bloc.add(const ScheduleFormUpdated());
      await submitDone;

      final submission = updateScheduleFormSubmissionUseCase.submissions.single;
      expect(submission.schedule.id, 'schedule-1');
      expect(submission.schedule.place.id, 'place-1');
      expect(submission.schedule.place.placeName, 'New Office');
      expect(submission.schedule.scheduleName, 'Edited Meeting');
      expect(submission.schedule.scheduleTime, DateTime(2027, 3, 21, 10, 30));
      expect(submission.schedule.moveTime, const Duration(minutes: 45));
      expect(
        submission.schedule.scheduleSpareTime,
        const Duration(minutes: 25),
      );
      expect(submission.preparationChanged, isFalse);
      expect(submission.originalPreparationMode, isNull);
    },
  );

  test('ScheduleFormUpdated emits submitting then failure on error', () async {
    updateScheduleFormSubmissionUseCase.handler = (_) =>
        Future.error(Exception('update'));
    final bloc = buildBloc();
    addTearDown(bloc.close);

    final submissionStatuses = <ScheduleFormSubmissionStatus>[];
    final subscription = bloc.stream
        .map((state) => state.submissionStatus)
        .listen(submissionStatuses.add);
    addTearDown(subscription.cancel);

    await primeEditState(bloc);

    final submitFailed = bloc.stream.firstWhere(
      (state) => state.submissionStatus == ScheduleFormSubmissionStatus.failure,
    );
    bloc.add(const ScheduleFormUpdated());
    await submitFailed;

    expect(
      submissionStatuses,
      containsAllInOrder([
        ScheduleFormSubmissionStatus.submitting,
        ScheduleFormSubmissionStatus.failure,
      ]),
    );
  });

  test(
    'ScheduleFormCreated persists custom preparation when changed',
    () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await primeCreateState(bloc);

      final changedPreparation = PreparationEntity(
        preparationStepList: const [
          PreparationStepEntity(
            id: 'prep-2',
            preparationName: 'Pack',
            preparationTime: Duration(minutes: 15),
          ),
        ],
      );
      bloc
        ..add(const ScheduleFormScheduleNameChanged(scheduleName: 'Meeting'))
        ..add(
          ScheduleFormScheduleDateTimeChanged(
            scheduleDate: DateTime(2027, 3, 20),
            scheduleTime: DateTime(2027, 3, 20, 9),
          ),
        )
        ..add(const ScheduleFormPlaceNameChanged(placeName: 'Office'))
        ..add(
          const ScheduleFormMoveTimeChanged(moveTime: Duration(minutes: 30)),
        )
        ..add(
          const ScheduleFormScheduleSpareTimeChanged(
            scheduleSpareTime: Duration(minutes: 10),
          ),
        )
        ..add(ScheduleFormPreparationChanged(preparation: changedPreparation));

      final submitDone = bloc.stream.firstWhere(
        (state) =>
            state.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      bloc.add(const ScheduleFormCreated());
      await submitDone;

      final submission = createScheduleFormSubmissionUseCase.submissions.single;
      expect(submission.schedule.id, 'schedule-1');
      expect(submission.preparation, changedPreparation);
      expect(submission.preparationChanged, isTrue);
    },
  );

  test('ScheduleFormPreparationChanged marks unchanged preparations', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    await primeEditState(bloc);

    bloc.add(ScheduleFormPreparationChanged(preparation: preparation));
    await pumpEventQueue();

    expect(bloc.state.isChanged, IsPreparationChanged.unchanged);
  });
}
