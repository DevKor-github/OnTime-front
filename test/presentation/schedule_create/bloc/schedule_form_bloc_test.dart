import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/product_usage_event.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/use-cases/track_product_usage_event_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedule_by_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_schedule_use_case.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';

class StubAuthBloc extends Mock implements AuthBloc {
  StubAuthBloc(this._state);

  final AuthState _state;

  @override
  AuthState get state => _state;
}

class StubLoadPreparationByScheduleIdUseCase
    implements LoadPreparationByScheduleIdUseCase {
  StubLoadPreparationByScheduleIdUseCase(this.handler);

  final Future<void> Function(String scheduleId) handler;

  @override
  Future<void> call(String scheduleId) => handler(scheduleId);
}

class StubGetPreparationByScheduleIdUseCase
    implements GetPreparationByScheduleIdUseCase {
  StubGetPreparationByScheduleIdUseCase(this.handler);

  final Future<PreparationEntity> Function(String scheduleId) handler;

  @override
  Future<PreparationEntity> call(String scheduleId) => handler(scheduleId);
}

class StubGetDefaultPreparationUseCase implements GetDefaultPreparationUseCase {
  StubGetDefaultPreparationUseCase(this.handler);

  final Future<PreparationEntity> Function() handler;

  @override
  Future<PreparationEntity> call() => handler();
}

class StubGetScheduleByIdUseCase implements GetScheduleByIdUseCase {
  StubGetScheduleByIdUseCase(this.handler);

  final Future<ScheduleEntity> Function(String id) handler;

  @override
  Future<ScheduleEntity> call(String id) => handler(id);
}

class StubCreateScheduleWithPlaceUseCase
    implements CreateScheduleWithPlaceUseCase {
  StubCreateScheduleWithPlaceUseCase(this.handler);

  final Future<void> Function(ScheduleEntity schedule) handler;

  @override
  Future<void> call(ScheduleEntity schedule) => handler(schedule);
}

class StubCreateCustomPreparationUseCase
    implements CreateCustomPreparationUseCase {
  StubCreateCustomPreparationUseCase(this.handler);

  final Future<void> Function(PreparationEntity preparation, String scheduleId)
  handler;

  @override
  Future<void> call(PreparationEntity preparationEntity, String scheduleId) {
    return handler(preparationEntity, scheduleId);
  }
}

class StubUpdateScheduleUseCase implements UpdateScheduleUseCase {
  StubUpdateScheduleUseCase(this.handler);

  final Future<void> Function(ScheduleEntity schedule) handler;

  @override
  Future<void> call(
    ScheduleEntity schedule, {
    bool includePreparationSource = false,
  }) => handler(schedule);
}

class StubUpdatePreparationByScheduleIdUseCase
    implements UpdatePreparationByScheduleIdUseCase {
  StubUpdatePreparationByScheduleIdUseCase(this.handler);

  final Future<void> Function(PreparationEntity preparation, String scheduleId)
  handler;

  @override
  Future<void> call(PreparationEntity preparationEntity, String scheduleId) {
    return handler(preparationEntity, scheduleId);
  }
}

class StubProductUsageEventTracker implements ProductUsageEventTracker {
  final events = <ProductUsageEvent>[];

  @override
  Future<void> track(ProductUsageEvent event) async {
    events.add(event);
  }
}

void main() {
  late StubLoadPreparationByScheduleIdUseCase
  loadPreparationByScheduleIdUseCase;
  late StubGetPreparationByScheduleIdUseCase getPreparationByScheduleIdUseCase;
  late StubGetDefaultPreparationUseCase getDefaultPreparationUseCase;
  late StubGetScheduleByIdUseCase getScheduleByIdUseCase;
  late StubCreateScheduleWithPlaceUseCase createScheduleWithPlaceUseCase;
  late StubCreateCustomPreparationUseCase createCustomPreparationUseCase;
  late StubUpdateScheduleUseCase updateScheduleUseCase;
  late StubUpdatePreparationByScheduleIdUseCase
  updatePreparationByScheduleIdUseCase;
  late StubProductUsageEventTracker productUsageEventTracker;
  late StubAuthBloc authBloc;

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

  ScheduleFormBloc buildBloc() {
    return ScheduleFormBloc(
      loadPreparationByScheduleIdUseCase,
      getPreparationByScheduleIdUseCase,
      getDefaultPreparationUseCase,
      getScheduleByIdUseCase,
      createScheduleWithPlaceUseCase,
      createCustomPreparationUseCase,
      updateScheduleUseCase,
      updatePreparationByScheduleIdUseCase,
      productUsageEventTracker,
      authBloc,
    );
  }

  setUp(() {
    loadPreparationByScheduleIdUseCase = StubLoadPreparationByScheduleIdUseCase(
      (_) async {},
    );
    getPreparationByScheduleIdUseCase = StubGetPreparationByScheduleIdUseCase(
      (_) async => preparation,
    );
    getDefaultPreparationUseCase = StubGetDefaultPreparationUseCase(
      () async => preparation,
    );
    getScheduleByIdUseCase = StubGetScheduleByIdUseCase((_) async => schedule);
    createScheduleWithPlaceUseCase = StubCreateScheduleWithPlaceUseCase(
      (_) async {},
    );
    createCustomPreparationUseCase = StubCreateCustomPreparationUseCase(
      (_, __) async {},
    );
    updateScheduleUseCase = StubUpdateScheduleUseCase((_) async {});
    updatePreparationByScheduleIdUseCase =
        StubUpdatePreparationByScheduleIdUseCase((_, __) async {});
    productUsageEventTracker = StubProductUsageEventTracker();

    authBloc = StubAuthBloc(
      AuthState(
        user: UserEntity(
          id: 'user-1',
          email: 'user@test.com',
          name: 'tester',
          spareTime: const Duration(minutes: 5),
          note: '',
          score: 1,
          isOnboardingCompleted: true,
        ),
      ),
    );
  });

  test('ScheduleFormUpdated emits submitting then success', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    final submissionStatuses = <ScheduleFormSubmissionStatus>[];
    final subscription = bloc.stream
        .map((state) => state.submissionStatus)
        .listen(submissionStatuses.add);
    addTearDown(subscription.cancel);

    final editReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
    await editReady;

    final submitDone = bloc.stream.firstWhere(
      (state) => state.submissionStatus == ScheduleFormSubmissionStatus.success,
    );
    bloc.add(const ScheduleFormUpdated());
    await submitDone;

    expect(
      submissionStatuses,
      containsAllInOrder([
        ScheduleFormSubmissionStatus.submitting,
        ScheduleFormSubmissionStatus.success,
      ]),
    );
  });

  test(
    'ScheduleFormUpdated sends edited schedule fields to update use case',
    () async {
      ScheduleEntity? updatedSchedule;
      updateScheduleUseCase = StubUpdateScheduleUseCase((schedule) async {
        updatedSchedule = schedule;
      });

      final bloc = buildBloc();
      addTearDown(bloc.close);

      final editReady = bloc.stream.firstWhere(
        (state) => state.status == ScheduleFormStatus.success,
      );
      bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
      await editReady;

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

      expect(updatedSchedule, isNotNull);
      expect(updatedSchedule!.id, 'schedule-1');
      expect(updatedSchedule!.place.id, 'place-1');
      expect(updatedSchedule!.place.placeName, 'New Office');
      expect(updatedSchedule!.scheduleName, 'Edited Meeting');
      expect(updatedSchedule!.scheduleTime, DateTime(2027, 3, 21, 10, 30));
      expect(updatedSchedule!.moveTime, const Duration(minutes: 45));
      expect(updatedSchedule!.scheduleSpareTime, const Duration(minutes: 25));
    },
  );

  test('ScheduleFormUpdated emits submitting then failure on error', () async {
    updateScheduleUseCase = StubUpdateScheduleUseCase(
      (_) => Future.error(Exception('update')),
    );

    final bloc = buildBloc();
    addTearDown(bloc.close);

    final submissionStatuses = <ScheduleFormSubmissionStatus>[];
    final subscription = bloc.stream
        .map((state) => state.submissionStatus)
        .listen(submissionStatuses.add);
    addTearDown(subscription.cancel);

    final editReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
    await editReady;

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

  test('ScheduleFormCreated emits submitting then success', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    final submissionStatuses = <ScheduleFormSubmissionStatus>[];
    final subscription = bloc.stream
        .map((state) => state.submissionStatus)
        .listen(submissionStatuses.add);
    addTearDown(subscription.cancel);

    final createReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormCreateRequested());
    await createReady;

    bloc.add(const ScheduleFormScheduleNameChanged(scheduleName: 'Meeting'));
    bloc.add(
      ScheduleFormScheduleDateTimeChanged(
        scheduleDate: DateTime(2027, 3, 20),
        scheduleTime: DateTime(2027, 3, 20, 9, 0),
      ),
    );
    bloc.add(const ScheduleFormPlaceNameChanged(placeName: 'Office'));
    bloc.add(
      const ScheduleFormMoveTimeChanged(moveTime: Duration(minutes: 30)),
    );
    bloc.add(
      const ScheduleFormScheduleSpareTimeChanged(
        scheduleSpareTime: Duration(minutes: 10),
      ),
    );

    final submitDone = bloc.stream.firstWhere(
      (state) => state.submissionStatus == ScheduleFormSubmissionStatus.success,
    );
    bloc.add(const ScheduleFormCreated());
    await submitDone;

    expect(
      submissionStatuses,
      containsAllInOrder([
        ScheduleFormSubmissionStatus.submitting,
        ScheduleFormSubmissionStatus.success,
      ]),
    );
  });

  test('ScheduleFormCreated tracks schedule_created after success', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    final createReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormCreateRequested());
    await createReady;

    bloc
      ..add(const ScheduleFormScheduleNameChanged(scheduleName: 'Meeting'))
      ..add(
        ScheduleFormScheduleDateTimeChanged(
          scheduleDate: DateTime(2027, 3, 20),
          scheduleTime: DateTime(2027, 3, 20, 9),
        ),
      )
      ..add(const ScheduleFormPlaceNameChanged(placeName: 'Office'))
      ..add(const ScheduleFormMoveTimeChanged(moveTime: Duration(minutes: 30)))
      ..add(
        const ScheduleFormScheduleSpareTimeChanged(
          scheduleSpareTime: Duration(minutes: 10),
        ),
      );

    final submitDone = bloc.stream.firstWhere(
      (state) => state.submissionStatus == ScheduleFormSubmissionStatus.success,
    );
    bloc.add(const ScheduleFormCreated());
    await submitDone;

    expect(productUsageEventTracker.events, hasLength(1));
    expect(productUsageEventTracker.events.single.name, 'schedule_created');
    expect(productUsageEventTracker.events.single.workflow, 'schedule');
    expect(productUsageEventTracker.events.single.result, 'success');
    expect(
      productUsageEventTracker.events.single.parameters,
      containsPair('preparation_step_count', 1),
    );
  });

  test('ScheduleFormCreateRequested seeds a provided future date', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    final createReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(ScheduleFormCreateRequested(initialDate: DateTime(2027, 4, 5)));
    final state = await createReady;

    expect(state.scheduleTime, isNotNull);
    expect(state.scheduleTime!.year, 2027);
    expect(state.scheduleTime!.month, 4);
    expect(state.scheduleTime!.day, 5);
    expect(state.scheduleSpareTime, const Duration(minutes: 5));
  });

  test('ScheduleFormPreparationChanged marks unchanged preparations', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    final editReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
    await editReady;

    bloc.add(ScheduleFormPreparationChanged(preparation: preparation));
    await pumpEventQueue();

    expect(bloc.state.isChanged, IsPreparationChanged.unchanged);
  });

  test('ScheduleFormUpdated skips preparation update when unchanged', () async {
    var preparationUpdateCount = 0;
    updatePreparationByScheduleIdUseCase =
        StubUpdatePreparationByScheduleIdUseCase((_, __) async {
          preparationUpdateCount += 1;
        });
    final bloc = buildBloc();
    addTearDown(bloc.close);

    final editReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
    await editReady;

    final submitDone = bloc.stream.firstWhere(
      (state) => state.submissionStatus == ScheduleFormSubmissionStatus.success,
    );
    bloc.add(const ScheduleFormUpdated());
    await submitDone;

    expect(preparationUpdateCount, 0);
  });

  test(
    'ScheduleFormUpdated copies default preparation with fresh step IDs',
    () async {
      getScheduleByIdUseCase = StubGetScheduleByIdUseCase(
        (_) async => schedule.copyWith(
          preparationMode: SchedulePreparationMode.defaultPreparation,
        ),
      );

      PreparationEntity? updatedPreparation;
      updatePreparationByScheduleIdUseCase =
          StubUpdatePreparationByScheduleIdUseCase((preparation, _) async {
            updatedPreparation = preparation;
          });

      final bloc = buildBloc();
      addTearDown(bloc.close);

      final editReady = bloc.stream.firstWhere(
        (state) => state.status == ScheduleFormStatus.success,
      );
      bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
      await editReady;

      const editedPreparation = PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'default-step-1',
            preparationName: 'Makeup',
            preparationTime: Duration(minutes: 20),
            nextPreparationId: 'default-step-2',
          ),
          PreparationStepEntity(
            id: 'default-step-2',
            preparationName: 'Bathroom',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      );
      bloc.add(
        const ScheduleFormPreparationChanged(preparation: editedPreparation),
      );

      final submitDone = bloc.stream.firstWhere(
        (state) =>
            state.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      bloc.add(const ScheduleFormUpdated());
      await submitDone;

      final steps = updatedPreparation!.preparationStepList;
      expect(steps, hasLength(2));
      expect(steps[0].preparationName, 'Makeup');
      expect(steps[0].preparationTime, const Duration(minutes: 20));
      expect(steps[1].preparationName, 'Bathroom');
      expect(steps[1].preparationTime, const Duration(minutes: 5));
      expect(steps[0].id, isNot('default-step-1'));
      expect(steps[1].id, isNot('default-step-2'));
      expect(steps[0].nextPreparationId, steps[1].id);
      expect(steps[1].nextPreparationId, isNull);
    },
  );

  test('ScheduleFormUpdated preserves custom preparation step IDs', () async {
    getScheduleByIdUseCase = StubGetScheduleByIdUseCase(
      (_) async =>
          schedule.copyWith(preparationMode: SchedulePreparationMode.custom),
    );

    PreparationEntity? updatedPreparation;
    updatePreparationByScheduleIdUseCase =
        StubUpdatePreparationByScheduleIdUseCase((preparation, _) async {
          updatedPreparation = preparation;
        });

    final bloc = buildBloc();
    addTearDown(bloc.close);

    final editReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormEditRequested(scheduleId: 'schedule-1'));
    await editReady;

    const editedPreparation = PreparationEntity(
      preparationStepList: [
        PreparationStepEntity(
          id: 'custom-step-1',
          preparationName: 'Makeup',
          preparationTime: Duration(minutes: 20),
          nextPreparationId: 'custom-step-2',
        ),
        PreparationStepEntity(
          id: 'custom-step-2',
          preparationName: 'Bathroom',
          preparationTime: Duration(minutes: 5),
        ),
      ],
    );
    bloc.add(
      const ScheduleFormPreparationChanged(preparation: editedPreparation),
    );

    final submitDone = bloc.stream.firstWhere(
      (state) => state.submissionStatus == ScheduleFormSubmissionStatus.success,
    );
    bloc.add(const ScheduleFormUpdated());
    await submitDone;

    final steps = updatedPreparation!.preparationStepList;
    expect(steps.map((step) => step.id), ['custom-step-1', 'custom-step-2']);
    expect(steps[0].nextPreparationId, 'custom-step-2');
    expect(steps[1].nextPreparationId, isNull);
  });

  test(
    'ScheduleFormCreated persists custom preparation when changed',
    () async {
      var customPreparationCount = 0;
      createCustomPreparationUseCase = StubCreateCustomPreparationUseCase((
        _,
        __,
      ) async {
        customPreparationCount += 1;
      });
      final bloc = buildBloc();
      addTearDown(bloc.close);

      final createReady = bloc.stream.firstWhere(
        (state) => state.status == ScheduleFormStatus.success,
      );
      bloc.add(const ScheduleFormCreateRequested());
      await createReady;

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

      expect(customPreparationCount, 1);
    },
  );

  test('ScheduleFormCreated emits submitting then failure on error', () async {
    createScheduleWithPlaceUseCase = StubCreateScheduleWithPlaceUseCase(
      (_) => Future.error(Exception()),
    );

    final bloc = buildBloc();
    addTearDown(bloc.close);

    final submissionStatuses = <ScheduleFormSubmissionStatus>[];
    final subscription = bloc.stream
        .map((state) => state.submissionStatus)
        .listen(submissionStatuses.add);
    addTearDown(subscription.cancel);

    final createReady = bloc.stream.firstWhere(
      (state) => state.status == ScheduleFormStatus.success,
    );
    bloc.add(const ScheduleFormCreateRequested());
    await createReady;

    bloc.add(const ScheduleFormScheduleNameChanged(scheduleName: 'Meeting'));
    bloc.add(
      ScheduleFormScheduleDateTimeChanged(
        scheduleDate: DateTime(2027, 3, 20),
        scheduleTime: DateTime(2027, 3, 20, 9, 0),
      ),
    );
    bloc.add(const ScheduleFormPlaceNameChanged(placeName: 'Office'));
    bloc.add(
      const ScheduleFormMoveTimeChanged(moveTime: Duration(minutes: 30)),
    );
    bloc.add(
      const ScheduleFormScheduleSpareTimeChanged(
        scheduleSpareTime: Duration(minutes: 10),
      ),
    );

    final submitFailed = bloc.stream.firstWhere(
      (state) => state.submissionStatus == ScheduleFormSubmissionStatus.failure,
    );
    bloc.add(const ScheduleFormCreated());
    await submitFailed;

    expect(
      submissionStatuses,
      containsAllInOrder([
        ScheduleFormSubmissionStatus.submitting,
        ScheduleFormSubmissionStatus.failure,
      ]),
    );
  });
}
