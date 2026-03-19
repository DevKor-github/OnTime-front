import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_month_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_preparations_use_case.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';

class StubLoadSchedulesForMonthUseCase implements LoadSchedulesForMonthUseCase {
  StubLoadSchedulesForMonthUseCase(this.handler);
  final Future<void> Function(DateTime date) handler;

  @override
  Future<void> call(DateTime date) => handler(date);
}

class StubGetSchedulesByDateUseCase implements GetSchedulesByDateUseCase {
  StubGetSchedulesByDateUseCase(this.handler);
  final Stream<List<ScheduleEntity>> Function(DateTime, DateTime) handler;

  @override
  Stream<List<ScheduleEntity>> call(DateTime startDate, DateTime endDate) {
    return handler(startDate, endDate);
  }
}

class StubDeleteScheduleUseCase implements DeleteScheduleUseCase {
  StubDeleteScheduleUseCase(this.handler);
  final Future<void> Function(ScheduleEntity schedule) handler;

  @override
  Future<void> call(ScheduleEntity schedule) => handler(schedule);
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

class StubStreamPreparationsUseCase implements StreamPreparationsUseCase {
  StubStreamPreparationsUseCase(this.handler);
  final Stream<Map<String, PreparationEntity>> Function() handler;

  @override
  Stream<Map<String, PreparationEntity>> call() => handler();
}

void main() {
  final selectedDate = DateTime(2026, 3, 20);
  final scheduleA = ScheduleEntity(
    id: 'schedule-a',
    place: PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Meeting',
    scheduleTime: DateTime(2026, 3, 20, 9, 0),
    moveTime: const Duration(minutes: 20),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 10),
    scheduleNote: '',
  );
  final scheduleB = ScheduleEntity(
    id: 'schedule-b',
    place: PlaceEntity(id: 'place-2', placeName: 'Cafe'),
    scheduleName: 'Coffee',
    scheduleTime: DateTime(2026, 3, 20, 11, 0),
    moveTime: const Duration(minutes: 15),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 5),
    scheduleNote: '',
  );

  late StubLoadSchedulesForMonthUseCase loadSchedulesForMonthUseCase;
  late StubGetSchedulesByDateUseCase getSchedulesByDateUseCase;
  late StubDeleteScheduleUseCase deleteScheduleUseCase;
  late StubLoadPreparationByScheduleIdUseCase
      loadPreparationByScheduleIdUseCase;
  late StubGetPreparationByScheduleIdUseCase getPreparationByScheduleIdUseCase;
  late StubStreamPreparationsUseCase streamPreparationsUseCase;

  late Map<String, int> loadCallsByScheduleId;
  late Stream<Map<String, PreparationEntity>> preparationsStream;

  MonthlySchedulesBloc buildBloc() {
    return MonthlySchedulesBloc(
      loadSchedulesForMonthUseCase,
      getSchedulesByDateUseCase,
      deleteScheduleUseCase,
      loadPreparationByScheduleIdUseCase,
      getPreparationByScheduleIdUseCase,
      streamPreparationsUseCase,
    );
  }

  setUp(() {
    loadCallsByScheduleId = {};

    loadSchedulesForMonthUseCase = StubLoadSchedulesForMonthUseCase(
      (_) async {},
    );
    getSchedulesByDateUseCase = StubGetSchedulesByDateUseCase(
      (_, __) => Stream<List<ScheduleEntity>>.fromIterable([
        [scheduleA, scheduleB],
      ]),
    );
    deleteScheduleUseCase = StubDeleteScheduleUseCase((_) async {});
    preparationsStream = const Stream.empty();
    streamPreparationsUseCase = StubStreamPreparationsUseCase(
      () => preparationsStream,
    );
    loadPreparationByScheduleIdUseCase = StubLoadPreparationByScheduleIdUseCase(
      (scheduleId) async {
        loadCallsByScheduleId[scheduleId] =
            (loadCallsByScheduleId[scheduleId] ?? 0) + 1;
      },
    );
    getPreparationByScheduleIdUseCase = StubGetPreparationByScheduleIdUseCase(
      (scheduleId) async {
        if (scheduleId == scheduleA.id) {
          return const PreparationEntity(
            preparationStepList: [
              PreparationStepEntity(
                id: 'prep-a',
                preparationName: 'Shower',
                preparationTime: Duration(minutes: 20),
              ),
            ],
          );
        }
        return const PreparationEntity(
          preparationStepList: [
            PreparationStepEntity(
              id: 'prep-b',
              preparationName: 'Dress',
              preparationTime: Duration(minutes: 15),
            ),
          ],
        );
      },
    );
  });

  test('visible date + schedules prefetches preparations for visible schedules',
      () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(MonthlySchedulesVisibleDateChanged(date: selectedDate));
    bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));

    final loadedState = await bloc.stream.firstWhere(
      (state) =>
          state.preparationDurationByScheduleId.containsKey(scheduleA.id) &&
          state.preparationDurationByScheduleId.containsKey(scheduleB.id),
    );

    expect(
      loadedState.preparationDurationByScheduleId[scheduleA.id],
      const Duration(minutes: 20),
    );
    expect(
      loadedState.preparationDurationByScheduleId[scheduleB.id],
      const Duration(minutes: 15),
    );
  });

  test('cached schedule preparations are not fetched again', () async {
    getSchedulesByDateUseCase = StubGetSchedulesByDateUseCase(
      (_, __) => Stream<List<ScheduleEntity>>.fromIterable([
        [scheduleA, scheduleB],
        [scheduleA, scheduleB],
      ]),
    );

    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(MonthlySchedulesVisibleDateChanged(date: selectedDate));
    bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));

    await bloc.stream.firstWhere(
      (state) =>
          state.preparationDurationByScheduleId.length == 2 &&
          state.preparationDurationByScheduleId.containsKey(scheduleA.id) &&
          state.preparationDurationByScheduleId.containsKey(scheduleB.id),
    );

    final beforeA = loadCallsByScheduleId[scheduleA.id] ?? 0;
    final beforeB = loadCallsByScheduleId[scheduleB.id] ?? 0;

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(loadCallsByScheduleId[scheduleA.id], beforeA);
    expect(loadCallsByScheduleId[scheduleB.id], beforeB);
  });

  test('stream update changes preparation time for cached schedule', () async {
    final controller = StreamController<Map<String, PreparationEntity>>();
    addTearDown(controller.close);
    preparationsStream = controller.stream;

    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(MonthlySchedulesVisibleDateChanged(date: selectedDate));
    bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
    await bloc.stream.firstWhere(
      (state) =>
          state.preparationDurationByScheduleId.containsKey(scheduleA.id) &&
          state.preparationDurationByScheduleId.containsKey(scheduleB.id),
    );

    controller.add({
      scheduleA.id: const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'prep-a-new',
            preparationName: 'Shower',
            preparationTime: Duration(minutes: 45),
          ),
        ],
      ),
    });

    final updatedState = await bloc.stream.firstWhere(
      (state) =>
          state.preparationDurationByScheduleId[scheduleA.id] ==
          const Duration(minutes: 45),
    );
    expect(
      updatedState.preparationDurationByScheduleId[scheduleB.id],
      const Duration(minutes: 15),
    );
  });

  test('stream update ignores schedules not cached in monthly state', () async {
    final controller = StreamController<Map<String, PreparationEntity>>();
    addTearDown(controller.close);
    preparationsStream = controller.stream;

    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(MonthlySchedulesVisibleDateChanged(date: selectedDate));
    bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
    final loadedState = await bloc.stream.firstWhere(
      (state) =>
          state.preparationDurationByScheduleId.containsKey(scheduleA.id) &&
          state.preparationDurationByScheduleId.containsKey(scheduleB.id),
    );

    controller.add({
      'not-cached': const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'prep-x',
            preparationName: 'Other',
            preparationTime: Duration(minutes: 99),
          ),
        ],
      ),
    });

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.preparationDurationByScheduleId,
        loadedState.preparationDurationByScheduleId);
  });

  test('deleting a schedule removes its cached preparation duration', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(MonthlySchedulesVisibleDateChanged(date: selectedDate));
    bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
    await bloc.stream.firstWhere(
      (state) =>
          state.preparationDurationByScheduleId.containsKey(scheduleA.id) &&
          state.preparationDurationByScheduleId.containsKey(scheduleB.id),
    );

    bloc.add(MonthlySchedulesScheduleDeleted(schedule: scheduleA));

    final deletedState = await bloc.stream.firstWhere(
      (state) =>
          !state.preparationDurationByScheduleId.containsKey(scheduleA.id),
    );
    expect(
      deletedState.preparationDurationByScheduleId[scheduleB.id],
      const Duration(minutes: 15),
    );
  });
}
