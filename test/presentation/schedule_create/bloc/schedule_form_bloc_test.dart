import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
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
  Future<void> call(ScheduleEntity schedule) => handler(schedule);
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
    scheduleTime: DateTime(2026, 3, 20, 9, 0),
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
      authBloc,
    );
  }

  setUp(() {
    loadPreparationByScheduleIdUseCase =
        StubLoadPreparationByScheduleIdUseCase((_) async {});
    getPreparationByScheduleIdUseCase =
        StubGetPreparationByScheduleIdUseCase((_) async => preparation);
    getDefaultPreparationUseCase =
        StubGetDefaultPreparationUseCase(() async => preparation);
    getScheduleByIdUseCase = StubGetScheduleByIdUseCase((_) async => schedule);
    createScheduleWithPlaceUseCase =
        StubCreateScheduleWithPlaceUseCase((_) async {});
    createCustomPreparationUseCase =
        StubCreateCustomPreparationUseCase((_, __) async {});
    updateScheduleUseCase = StubUpdateScheduleUseCase((_) async {});
    updatePreparationByScheduleIdUseCase =
        StubUpdatePreparationByScheduleIdUseCase((_, __) async {});

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

  test('ScheduleFormUpdated sends edited schedule fields to update use case',
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
        scheduleDate: DateTime(2026, 3, 21),
        scheduleTime: DateTime(2026, 3, 21, 10, 30),
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
      (state) => state.submissionStatus == ScheduleFormSubmissionStatus.success,
    );
    bloc.add(const ScheduleFormUpdated());
    await submitDone;

    expect(updatedSchedule, isNotNull);
    expect(updatedSchedule!.id, 'schedule-1');
    expect(updatedSchedule!.place.id, 'place-1');
    expect(updatedSchedule!.place.placeName, 'New Office');
    expect(updatedSchedule!.scheduleName, 'Edited Meeting');
    expect(updatedSchedule!.scheduleTime, DateTime(2026, 3, 21, 10, 30));
    expect(updatedSchedule!.moveTime, const Duration(minutes: 45));
    expect(
      updatedSchedule!.scheduleSpareTime,
      const Duration(minutes: 25),
    );
  });

  test('ScheduleFormUpdated emits submitting then failure on error', () async {
    updateScheduleUseCase =
        StubUpdateScheduleUseCase((_) => Future.error(Exception('update')));

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
        scheduleDate: DateTime(2026, 3, 20),
        scheduleTime: DateTime(2026, 3, 20, 9, 0),
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

  test('ScheduleFormCreated emits submitting then failure on error', () async {
    createScheduleWithPlaceUseCase =
        StubCreateScheduleWithPlaceUseCase((_) => Future.error(Exception()));

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
        scheduleDate: DateTime(2026, 3, 20),
        scheduleTime: DateTime(2026, 3, 20, 9, 0),
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
