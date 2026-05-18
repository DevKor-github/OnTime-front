import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_date_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/input_models/schedule_time_input_model.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  test('state combines selected date and time and clears overlap fields', () {
    final date = DateTime.now().add(const Duration(days: 3));
    final time = DateTime(2026, 1, 1, 9, 30);
    final state = ScheduleDateTimeState(
      scheduleDate: ScheduleDateInputModel.dirty(date),
      scheduleTime: ScheduleTimeInputModel.dirty(time),
      isOverlapping: true,
      nextScheduleName: 'Next',
      nextPreparationStartTime: DateTime(2026, 1, 1, 8),
      previousOverlapDuration: const Duration(minutes: 20),
      previousScheduleName: 'Previous',
    );

    expect(
      state.selectedScheduleDateTime,
      DateTime(date.year, date.month, date.day, 9, 30),
    );
    expect(state.hasAnyOverlapMessage, isTrue);

    final cleared = state.copyWith(
      clearOverlap: true,
      clearPreviousOverlap: true,
    );
    expect(cleared.isOverlapping, isFalse);
    expect(cleared.nextScheduleName, isNull);
    expect(cleared.nextPreparationStartTime, isNull);
    expect(cleared.previousOverlapDuration, isNull);
    expect(cleared.previousScheduleName, isNull);
  });

  testWidgets('state returns localized overlap and past-time messages', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final past = DateTime.now().subtract(const Duration(days: 1));
    final state = ScheduleDateTimeState(
      scheduleDate: ScheduleDateInputModel.dirty(past),
      scheduleTime: ScheduleTimeInputModel.dirty(past),
      isOverlapping: true,
      nextScheduleName: 'Next meeting',
      nextPreparationStartTime: DateTime(2026, 1, 1, 8),
      previousOverlapDuration: const Duration(minutes: 15),
      previousScheduleName: 'Previous meeting',
    );

    expect(state.getOverlapMessage(capturedContext), contains('Next meeting'));
    expect(
      state.getPreviousOverlapMessage(capturedContext),
      contains('Previous meeting'),
    );
    expect(state.getPastScheduleTimeMessage(capturedContext), isNotNull);
  });

  test(
    'date and time changes load adjacent schedules and validate form',
    () async {
      final formBloc = _FakeScheduleFormBloc();
      final loader = _FakeLoadAdjacentScheduleWithPreparationUseCase();
      final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
      final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent);
      addTearDown(cubit.close);
      final date = DateTime.now().add(const Duration(days: 2));
      final time = DateTime(date.year, date.month, date.day, 9, 30);

      await cubit.scheduleDateChanged(date);
      await cubit.scheduleTimeChanged(time);

      expect(loader.calls, [
        (
          DateTime(
            date.year,
            date.month,
            date.day,
          ).subtract(const Duration(days: 1)),
          DateTime(
            date.year,
            date.month,
            date.day,
          ).add(const Duration(days: 2)),
        ),
      ]);
      expect(
        adjacent.calls.single.selectedDateTime,
        DateTime(date.year, date.month, date.day, 9, 30),
      );
      expect(
        formBloc.addedEvents.whereType<ScheduleFormValidated>().map(
          (event) => event.isValid,
        ),
        containsAll([false, true]),
      );
    },
  );

  test('initialize validates invalid form state without loading schedules', () {
    final formBloc = _FakeScheduleFormBloc(state: ScheduleFormState());
    final loader = _FakeLoadAdjacentScheduleWithPreparationUseCase();
    final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
    final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent);
    addTearDown(cubit.close);

    cubit.initialize();
    cubit.validateCurrentSelection();

    expect(loader.calls, isEmpty);
    expect(adjacent.calls, isEmpty);
    expect(
      formBloc.addedEvents.whereType<ScheduleFormValidated>().map(
        (event) => event.isValid,
      ),
      [false, false],
    );
  });

  test(
    'initialize loads adjacent schedules for an editable scheduled time',
    () async {
      final scheduledAt = DateTime.now().add(const Duration(days: 2));
      final formBloc = _FakeScheduleFormBloc(
        state: ScheduleFormState(
          id: 'editing-schedule',
          scheduleTime: scheduledAt,
        ),
      );
      final loader = _FakeLoadAdjacentScheduleWithPreparationUseCase();
      final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
      final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent);
      addTearDown(cubit.close);

      cubit.initialize();
      await pumpEventQueue();

      expect(loader.calls, [
        (
          DateTime(
            scheduledAt.year,
            scheduledAt.month,
            scheduledAt.day,
          ).subtract(const Duration(days: 1)),
          DateTime(
            scheduledAt.year,
            scheduledAt.month,
            scheduledAt.day,
          ).add(const Duration(days: 2)),
        ),
      ]);
      expect(adjacent.calls.single.currentScheduleId, 'editing-schedule');
    },
  );

  test('overlap check marks next schedule conflicts as invalid', () async {
    final formBloc = _FakeScheduleFormBloc();
    final loader = _FakeLoadAdjacentScheduleWithPreparationUseCase();
    final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
    final selected = DateTime.now().add(const Duration(days: 2));
    adjacent.result = AdjacentSchedulesWithPreparationEntity(
      nextSchedule: _scheduleWithPreparation(
        id: 'next',
        name: 'Next meeting',
        scheduleTime: DateTime(selected.year, selected.month, selected.day, 9),
        preparationMinutes: 30,
      ),
    );
    final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent);
    addTearDown(cubit.close);

    await cubit.scheduleDateChanged(selected);
    await cubit.scheduleTimeChanged(
      DateTime(selected.year, selected.month, selected.day, 8, 45),
    );

    expect(cubit.state.isOverlapping, isTrue);
    expect(cubit.state.nextScheduleName, 'Next meeting');
    expect(cubit.scheduleDateTimeSubmitted(), isFalse);
  });

  test(
    'overlap check clears next conflict when next preparation starts later',
    () async {
      final formBloc = _FakeScheduleFormBloc();
      final loader = _FakeLoadAdjacentScheduleWithPreparationUseCase();
      final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
      final selected = DateTime.now().add(const Duration(days: 2));
      adjacent.result = AdjacentSchedulesWithPreparationEntity(
        nextSchedule: _scheduleWithPreparation(
          id: 'next',
          name: 'Later meeting',
          scheduleTime: DateTime(
            selected.year,
            selected.month,
            selected.day,
            10,
          ),
          preparationMinutes: 15,
        ),
      );
      final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent);
      addTearDown(cubit.close);

      await cubit.scheduleDateChanged(selected);
      await cubit.scheduleTimeChanged(
        DateTime(selected.year, selected.month, selected.day, 9),
      );

      expect(cubit.state.isOverlapping, isFalse);
      expect(cubit.state.nextScheduleName, isNull);
    },
  );

  test(
    'previous schedule branches retain warning context for small and large gaps',
    () async {
      final selected = DateTime.now().add(const Duration(days: 2));
      final formBloc = _FakeScheduleFormBloc();
      final loader = _FakeLoadAdjacentScheduleWithPreparationUseCase();
      final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
      adjacent.result = AdjacentSchedulesWithPreparationEntity(
        previousSchedule: _scheduleWithPreparation(
          id: 'previous',
          name: 'Previous meeting',
          scheduleTime: DateTime(
            selected.year,
            selected.month,
            selected.day,
            5,
          ),
          preparationMinutes: 10,
        ),
      );
      final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent);
      addTearDown(cubit.close);

      await cubit.scheduleDateChanged(selected);
      await cubit.scheduleTimeChanged(
        DateTime(selected.year, selected.month, selected.day, 9),
      );

      expect(cubit.state.previousScheduleName, 'Previous meeting');
      expect(cubit.state.previousOverlapDuration, const Duration(hours: 4));
      expect(cubit.state.hasPreviousOverlapMessage, isFalse);
    },
  );

  test('overlap errors clear stale overlap state and mark invalid', () async {
    final formBloc = _FakeScheduleFormBloc();
    final loader = _FakeLoadAdjacentScheduleWithPreparationUseCase();
    final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase()
      ..throwsOnCall = true;
    final selected = DateTime.now().add(const Duration(days: 2));
    final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent);
    addTearDown(cubit.close);

    await cubit.scheduleDateChanged(selected);
    await cubit.scheduleTimeChanged(
      DateTime(selected.year, selected.month, selected.day, 9),
    );

    expect(cubit.state.isOverlapping, isFalse);
    expect(cubit.state.previousOverlapDuration, isNull);
    expect(
      formBloc.addedEvents.whereType<ScheduleFormValidated>().last.isValid,
      isTrue,
    );
  });

  test(
    'submission forwards selected time and previous available gap',
    () async {
      final formBloc = _FakeScheduleFormBloc();
      final loader = _FakeLoadAdjacentScheduleWithPreparationUseCase();
      final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
      final selected = DateTime.now().add(const Duration(days: 2));
      adjacent.result = AdjacentSchedulesWithPreparationEntity(
        previousSchedule: _scheduleWithPreparation(
          id: 'previous',
          name: 'Previous meeting',
          scheduleTime: DateTime(
            selected.year,
            selected.month,
            selected.day,
            8,
          ),
          preparationMinutes: 10,
        ),
      );
      final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent);
      addTearDown(cubit.close);

      await cubit.scheduleDateChanged(selected);
      await cubit.scheduleTimeChanged(
        DateTime(selected.year, selected.month, selected.day, 8, 30),
      );

      expect(cubit.scheduleDateTimeSubmitted(), isTrue);
      final submitted = formBloc.addedEvents
          .whereType<ScheduleFormScheduleDateTimeChanged>()
          .single;
      expect(submitted.scheduleDate, selected);
      expect(submitted.scheduleTime.hour, 8);
      expect(submitted.scheduleTime.minute, 30);
      expect(submitted.maxAvailableTime, const Duration(minutes: 30));
      expect(submitted.previousScheduleName, 'Previous meeting');
    },
  );
}

ScheduleWithPreparationEntity _scheduleWithPreparation({
  required String id,
  required String name,
  required DateTime scheduleTime,
  required int preparationMinutes,
}) {
  return ScheduleWithPreparationEntity(
    id: id,
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: name,
    scheduleTime: scheduleTime,
    moveTime: Duration.zero,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration.zero,
    scheduleNote: '',
    preparation: PreparationWithTimeEntity(
      preparationStepList: [
        PreparationStepWithTimeEntity(
          id: 'prep-$id',
          preparationName: 'Prepare',
          preparationTime: Duration(minutes: preparationMinutes),
          nextPreparationId: null,
        ),
      ],
    ),
  );
}

class _FakeScheduleFormBloc implements ScheduleFormBloc {
  _FakeScheduleFormBloc({ScheduleFormState? state})
    : _state = state ?? ScheduleFormState(id: 'current-schedule');

  final addedEvents = <ScheduleFormEvent>[];
  final ScheduleFormState _state;

  @override
  ScheduleFormState get state => _state;

  @override
  void add(ScheduleFormEvent event) {
    addedEvents.add(event);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLoadAdjacentScheduleWithPreparationUseCase
    implements LoadAdjacentScheduleWithPreparationUseCase {
  final calls = <(DateTime, DateTime)>[];

  @override
  Future<void> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    calls.add((startDate, endDate));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AdjacentCall {
  const _AdjacentCall({
    required this.selectedDateTime,
    required this.currentScheduleId,
    required this.startDate,
    required this.endDate,
  });

  final DateTime selectedDateTime;
  final String? currentScheduleId;
  final DateTime startDate;
  final DateTime endDate;
}

class _FakeGetAdjacentSchedulesWithPreparationUseCase
    implements GetAdjacentSchedulesWithPreparationUseCase {
  AdjacentSchedulesWithPreparationEntity result =
      const AdjacentSchedulesWithPreparationEntity();
  final calls = <_AdjacentCall>[];
  bool throwsOnCall = false;

  @override
  Future<AdjacentSchedulesWithPreparationEntity> call({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    calls.add(
      _AdjacentCall(
        selectedDateTime: selectedDateTime,
        currentScheduleId: currentScheduleId,
        startDate: startDate,
        endDate: endDate,
      ),
    );
    if (throwsOnCall) {
      throw Exception('adjacent schedules unavailable');
    }
    return result;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
