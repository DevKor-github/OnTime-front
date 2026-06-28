import 'dart:async';

import 'package:dio/dio.dart';
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

class _TrackedScheduleStream {
  _TrackedScheduleStream({
    required this.startDate,
    required this.endDate,
    required void Function() onListen,
    required void Function() onCancel,
  }) : controller = StreamController<List<ScheduleEntity>>(
         onListen: onListen,
         onCancel: onCancel,
       );

  final DateTime startDate;
  final DateTime endDate;
  final StreamController<List<ScheduleEntity>> controller;

  void add(List<ScheduleEntity> schedules) {
    controller.add(schedules);
  }

  Future<void> close() => controller.close();
}

Future<void> _waitFor(
  bool Function() condition, {
  String reason = 'condition was not met',
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  if (!condition()) {
    fail(reason);
  }
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
    getPreparationByScheduleIdUseCase = StubGetPreparationByScheduleIdUseCase((
      scheduleId,
    ) async {
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
    });
  });

  test(
    'visible date + schedules prefetches preparations for visible schedules',
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
    },
  );

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
    expect(
      bloc.state.preparationDurationByScheduleId,
      loadedState.preparationDurationByScheduleId,
    );
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

  test(
    'schedule stream update refreshes schedule fields in monthly state',
    () async {
      final controller = StreamController<List<ScheduleEntity>>();
      addTearDown(controller.close);
      getSchedulesByDateUseCase = StubGetSchedulesByDateUseCase(
        (_, __) => controller.stream,
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(MonthlySchedulesVisibleDateChanged(date: selectedDate));
      bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));

      controller.add([scheduleA, scheduleB]);
      await bloc.stream.firstWhere(
        (state) =>
            state.schedules[selectedDate]?.any(
              (schedule) => schedule.scheduleName == 'Meeting',
            ) ??
            false,
      );

      final updatedScheduleA = ScheduleEntity(
        id: scheduleA.id,
        place: PlaceEntity(id: scheduleA.place.id, placeName: 'New Office'),
        scheduleName: 'Edited Meeting',
        scheduleTime: DateTime(2026, 3, 20, 10, 30),
        moveTime: const Duration(minutes: 45),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 20),
        scheduleNote: '',
      );

      final updatedStateFuture = bloc.stream.firstWhere(
        (state) =>
            state.schedules[selectedDate]?.any(
              (schedule) =>
                  schedule.id == scheduleA.id &&
                  schedule.scheduleName == 'Edited Meeting' &&
                  schedule.place.placeName == 'New Office' &&
                  schedule.scheduleTime == DateTime(2026, 3, 20, 10, 30),
            ) ??
            false,
      );
      controller.add([updatedScheduleA, scheduleB]);
      final updatedState = await updatedStateFuture;

      final updatedSchedule = updatedState.schedules[selectedDate]!.firstWhere(
        (schedule) => schedule.id == scheduleA.id,
      );
      expect(updatedSchedule.scheduleName, 'Edited Meeting');
      expect(updatedSchedule.place.placeName, 'New Office');
      expect(updatedSchedule.scheduleTime, DateTime(2026, 3, 20, 10, 30));
      expect(updatedSchedule.moveTime, const Duration(minutes: 45));
      expect(updatedSchedule.scheduleSpareTime, const Duration(minutes: 20));
    },
  );

  test(
    'adjacent Calendar Month Range changes keep one active schedule listener',
    () async {
      final trackedStreams = <_TrackedScheduleStream>[];
      var activeListeners = 0;
      getSchedulesByDateUseCase = StubGetSchedulesByDateUseCase((
        startDate,
        endDate,
      ) {
        final trackedStream = _TrackedScheduleStream(
          startDate: startDate,
          endDate: endDate,
          onListen: () => activeListeners++,
          onCancel: () => activeListeners--,
        );
        trackedStreams.add(trackedStream);
        addTearDown(trackedStream.close);
        return trackedStream.controller.stream;
      });

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
      await _waitFor(
        () => trackedStreams.length == 1 && activeListeners == 1,
        reason: 'initial schedule listener was not attached',
      );
      trackedStreams.single.add([scheduleA]);
      await bloc.stream.firstWhere(
        (state) => state.status == MonthlySchedulesStatus.success,
      );

      bloc.add(MonthlySchedulesMonthAdded(date: DateTime(2026, 4, 1)));
      await _waitFor(
        () =>
            trackedStreams.length == 2 &&
            trackedStreams.last.startDate == DateTime(2026, 3, 1) &&
            trackedStreams.last.endDate == DateTime(2026, 5, 1),
        reason: 'April Calendar Month Range listener was not attached',
      );
      await _waitFor(
        () => activeListeners == 1,
        reason: 'April Calendar Month Range left stale listeners active',
      );
      trackedStreams.last.add([scheduleA]);
      await bloc.stream.firstWhere(
        (state) => state.endDate == DateTime(2026, 5, 1),
      );

      bloc.add(MonthlySchedulesMonthAdded(date: DateTime(2026, 5, 1)));
      await _waitFor(
        () =>
            trackedStreams.length == 3 &&
            trackedStreams.last.startDate == DateTime(2026, 3, 1) &&
            trackedStreams.last.endDate == DateTime(2026, 6, 1),
        reason: 'May Calendar Month Range listener was not attached',
      );
      await _waitFor(
        () => activeListeners == 1,
        reason: 'repeated Calendar Month Range changes accumulated listeners',
      );
    },
  );

  test(
    'stale schedule stream cannot overwrite newer Calendar Month Range',
    () async {
      final trackedStreams = <_TrackedScheduleStream>[];
      var activeListeners = 0;
      getSchedulesByDateUseCase = StubGetSchedulesByDateUseCase((
        startDate,
        endDate,
      ) {
        final trackedStream = _TrackedScheduleStream(
          startDate: startDate,
          endDate: endDate,
          onListen: () => activeListeners++,
          onCancel: () => activeListeners--,
        );
        trackedStreams.add(trackedStream);
        addTearDown(trackedStream.close);
        return trackedStream.controller.stream;
      });

      final julySchedule = ScheduleEntity(
        id: 'schedule-july',
        place: PlaceEntity(id: 'place-july', placeName: 'Station'),
        scheduleName: 'July planning',
        scheduleTime: DateTime(2026, 7, 8, 14),
        moveTime: const Duration(minutes: 5),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
      await _waitFor(
        () => trackedStreams.length == 1 && activeListeners == 1,
        reason: 'initial schedule listener was not attached',
      );
      trackedStreams.first.add([scheduleA]);
      await bloc.stream.firstWhere(
        (state) => state.startDate == DateTime(2026, 3, 1),
      );

      bloc.add(MonthlySchedulesMonthAdded(date: DateTime(2026, 7, 1)));
      await _waitFor(
        () =>
            trackedStreams.length == 2 &&
            activeListeners == 1 &&
            trackedStreams.last.startDate == DateTime(2026, 7, 1) &&
            trackedStreams.last.endDate == DateTime(2026, 8, 1),
        reason: 'July Calendar Month Range listener was not attached cleanly',
      );
      trackedStreams.last.add([julySchedule]);
      await bloc.stream.firstWhere(
        (state) =>
            state.startDate == DateTime(2026, 7, 1) &&
            (state.schedules[DateTime(2026, 7, 8)]?.contains(julySchedule) ??
                false),
      );

      trackedStreams.first.add([scheduleA]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(activeListeners, 1);
      expect(bloc.state.startDate, DateTime(2026, 7, 1));
      expect(bloc.state.endDate, DateTime(2026, 8, 1));
      expect(bloc.state.schedules[DateTime(2026, 3, 20)], isNull);
      expect(bloc.state.schedules[DateTime(2026, 7, 8)], [julySchedule]);
    },
  );

  test('refresh requested reloads schedules for current month', () async {
    var loadedDate = DateTime(2000);
    loadSchedulesForMonthUseCase = StubLoadSchedulesForMonthUseCase((
      date,
    ) async {
      loadedDate = date;
    });

    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(MonthlySchedulesRefreshRequested(date: DateTime(2026, 3, 20)));

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loadedDate, DateTime(2026, 3, 20));
  });

  test('initial load failure emits error state instead of throwing', () async {
    loadSchedulesForMonthUseCase = StubLoadSchedulesForMonthUseCase(
      (_) async => throw Exception('unauthorized'),
    );

    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));

    final errorState = await bloc.stream.firstWhere(
      (state) => state.status == MonthlySchedulesStatus.error,
    );

    expect(errorState.status, MonthlySchedulesStatus.error);
  });

  test(
    'month already in loaded range reuses cached range without reloading',
    () async {
      final loadedDates = <DateTime>[];
      loadSchedulesForMonthUseCase = StubLoadSchedulesForMonthUseCase((
        date,
      ) async {
        loadedDates.add(date);
      });

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
      await bloc.stream.firstWhere(
        (state) => state.status == MonthlySchedulesStatus.success,
      );

      bloc.add(MonthlySchedulesMonthAdded(date: DateTime(2026, 3, 1)));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(loadedDates, [selectedDate]);
      expect(bloc.state.startDate, DateTime(2026, 3, 1));
      expect(bloc.state.endDate, DateTime(2026, 4, 1));
    },
  );

  test(
    'adjacent month extends loaded range and groups returned schedules',
    () async {
      final loadedDates = <DateTime>[];
      loadSchedulesForMonthUseCase = StubLoadSchedulesForMonthUseCase((
        date,
      ) async {
        loadedDates.add(date);
      });

      final aprilSchedule = ScheduleEntity(
        id: 'schedule-april',
        place: PlaceEntity(id: 'place-3', placeName: 'Library'),
        scheduleName: 'April review',
        scheduleTime: DateTime(2026, 4, 2, 9),
        moveTime: const Duration(minutes: 10),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
      );
      getSchedulesByDateUseCase = StubGetSchedulesByDateUseCase(
        (_, __) => Stream.value([scheduleA, aprilSchedule]),
      );

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
      await bloc.stream.firstWhere(
        (state) => state.status == MonthlySchedulesStatus.success,
      );

      bloc.add(MonthlySchedulesMonthAdded(date: DateTime(2026, 4, 1)));
      final extendedState = await bloc.stream.firstWhere(
        (state) =>
            state.endDate == DateTime(2026, 5, 1) &&
            (state.schedules[DateTime(2026, 4, 2)]?.contains(aprilSchedule) ??
                false),
      );

      expect(loadedDates, [selectedDate, DateTime(2026, 4, 1)]);
      expect(extendedState.startDate, DateTime(2026, 3, 1));
      expect(extendedState.endDate, DateTime(2026, 5, 1));
    },
  );

  test('non-consecutive month replaces the subscription range', () async {
    final loadedDates = <DateTime>[];
    loadSchedulesForMonthUseCase = StubLoadSchedulesForMonthUseCase((
      date,
    ) async {
      loadedDates.add(date);
    });

    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
    await bloc.stream.firstWhere(
      (state) => state.status == MonthlySchedulesStatus.success,
    );

    bloc.add(MonthlySchedulesMonthAdded(date: DateTime(2026, 7, 1)));
    final reloadedState = await bloc.stream.firstWhere(
      (state) => state.startDate == DateTime(2026, 7, 1),
    );

    expect(loadedDates, [selectedDate, DateTime(2026, 7, 1)]);
    expect(reloadedState.endDate, DateTime(2026, 8, 1));
  });

  test(
    'adjacent month load failure emits error without dropping schedules',
    () async {
      var shouldFail = false;
      loadSchedulesForMonthUseCase = StubLoadSchedulesForMonthUseCase((
        date,
      ) async {
        if (shouldFail) {
          throw Exception('network down');
        }
      });

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(MonthlySchedulesSubscriptionRequested(date: selectedDate));
      final loadedState = await bloc.stream.firstWhere(
        (state) => state.status == MonthlySchedulesStatus.success,
      );

      shouldFail = true;
      bloc.add(MonthlySchedulesMonthAdded(date: DateTime(2026, 4, 1)));
      final errorState = await bloc.stream.firstWhere(
        (state) => state.status == MonthlySchedulesStatus.error,
      );

      expect(errorState.schedules, loadedState.schedules);
    },
  );

  test(
    'delete failure keeps calendar state and emits a delete failure signal',
    () async {
      deleteScheduleUseCase = StubDeleteScheduleUseCase(
        (_) async => throw DioException(
          requestOptions: RequestOptions(path: '/schedules/schedule-a'),
          response: Response(
            requestOptions: RequestOptions(path: '/schedules/schedule-a'),
            statusCode: 409,
            data: {
              'status': 'error',
              'code': 'SCHEDULE_ALREADY_FINISHED',
              'message': 'Finished schedules cannot be deleted.',
              'data': null,
            },
          ),
        ),
      );

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
      final failureState = await bloc.stream.firstWhere(
        (state) => state.deleteFailureCount == 1,
      );

      expect(failureState.status, MonthlySchedulesStatus.success);
      expect(failureState.lastDeletedSchedule, isNull);
      expect(
        failureState.deleteFailureMessage,
        'Finished schedules cannot be deleted.',
      );
      expect(
        failureState.preparationDurationByScheduleId[scheduleA.id],
        const Duration(minutes: 20),
      );
    },
  );

  test(
    'preparation prefetch ignores failed schedule preparation loads',
    () async {
      loadPreparationByScheduleIdUseCase =
          StubLoadPreparationByScheduleIdUseCase((scheduleId) async {
            if (scheduleId == scheduleA.id) {
              throw Exception('missing preparation');
            }
          });

      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(
        MonthlySchedulesPreparationsPrefetchRequested(
          scheduleIds: [scheduleA.id, scheduleB.id],
        ),
      );

      final prefetchedState = await bloc.stream.firstWhere(
        (state) =>
            state.preparationDurationByScheduleId.containsKey(scheduleB.id),
      );

      expect(
        prefetchedState.preparationDurationByScheduleId[scheduleA.id],
        isNull,
      );
      expect(
        prefetchedState.preparationDurationByScheduleId[scheduleB.id],
        const Duration(minutes: 15),
      );
    },
  );

  test('events and state expose value semantics used by the UI', () {
    final refresh = MonthlySchedulesRefreshRequested(
      date: DateTime(2026, 3, 20, 12),
    );
    final visible = MonthlySchedulesVisibleDateChanged(
      date: DateTime(2026, 3, 20, 12),
    );

    expect(
      MonthlySchedulesSubscriptionRequested(date: DateTime(2026, 3, 20)).props,
      [DateTime(2026, 3, 1), DateTime(2026, 4, 1)],
    );
    expect(MonthlySchedulesMonthAdded(date: DateTime(2026, 3, 20)).props, [
      DateTime(2026, 3, 20),
    ]);
    expect(
      MonthlySchedulesMonthAdded(date: DateTime(2026, 12, 31)).startDate,
      DateTime(2026, 12, 1),
    );
    expect(
      MonthlySchedulesMonthAdded(date: DateTime(2026, 12, 31)).endDate,
      DateTime(2027, 1, 1),
    );
    expect(refresh.props, [2026, 3]);
    expect(visible.props, [2026, 3, 20]);
    expect(MonthlySchedulesScheduleDeleted(schedule: scheduleA).props, [
      scheduleA,
    ]);
    expect(
      MonthlySchedulesPreparationsPrefetchRequested(
        scheduleIds: [scheduleA.id],
      ).props,
      [
        [scheduleA.id],
      ],
    );
    expect(
      MonthlySchedulesPreparationsStreamChanged(
        preparations: const {
          'schedule-a': PreparationEntity(preparationStepList: []),
        },
      ).props,
      [
        const {'schedule-a': PreparationEntity(preparationStepList: [])},
      ],
    );

    final state = MonthlySchedulesState(
      status: MonthlySchedulesStatus.loading,
      schedules: {
        selectedDate: [scheduleA],
      },
      preparationDurationByScheduleId: {
        scheduleA.id: const Duration(minutes: 10),
      },
      lastDeletedSchedule: scheduleB,
      deleteFailureMessage: 'Cannot delete.',
      deleteFailureCount: 2,
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 4, 1),
      visibleDate: selectedDate,
    );
    final copied = state.copyWith(
      status: () => MonthlySchedulesStatus.success,
      preparationDurationByScheduleId: () => const {},
      lastDeletedSchedule: () => null,
      deleteFailureMessage: () => null,
      deleteFailureCount: () => 3,
    );

    expect(copied.status, MonthlySchedulesStatus.success);
    expect(copied.schedules, state.schedules);
    expect(copied.preparationDurationByScheduleId, isEmpty);
    expect(copied.lastDeletedSchedule, isNull);
    expect(copied.deleteFailureMessage, isNull);
    expect(copied.deleteFailureCount, 3);
    expect(copied.startDate, state.startDate);
    expect(copied.endDate, state.endDate);
    expect(copied.visibleDate, state.visibleDate);
  });
}
