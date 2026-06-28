import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_month_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_week_use_case.dart';

void main() {
  test(
    'GetSchedulesByDateUseCase watches requested schedule date range',
    () async {
      final repository = _FakeScheduleRepository();
      final useCase = GetSchedulesByDateUseCase(repository);
      final start = DateTime(2026, 5, 10);
      final end = DateTime(2026, 5, 17);
      repository.watchResult = [
        _schedule('inside-later', DateTime(2026, 5, 12, 9)),
        _schedule('inside-start', DateTime(2026, 5, 10)),
      ];

      final result = await useCase(start, end).first;

      expect(repository.watchedRanges, [(start, end)]);
      expect(result.map((schedule) => schedule.id), [
        'inside-later',
        'inside-start',
      ]);
    },
  );

  test(
    'LoadSchedulesByDateUseCase forwards requested range to repository',
    () async {
      final repository = _FakeScheduleRepository();
      final useCase = LoadSchedulesByDateUseCase(repository);
      final start = DateTime(2026, 5, 10);
      final end = DateTime(2026, 5, 17);

      await useCase(start, end);

      expect(repository.loadedRanges, [(start, end)]);
    },
  );

  test(
    'LoadSchedulesForMonthUseCase loads the selected calendar month',
    () async {
      final recorder = _RecordingLoadSchedulesByDateUseCase();
      final useCase = LoadSchedulesForMonthUseCase(recorder);

      await useCase(DateTime(2026, 2, 14));

      expect(recorder.calls, [(DateTime(2026, 2), DateTime(2026, 3))]);
    },
  );

  test(
    'LoadSchedulesForWeekUseCase loads Monday through next Monday',
    () async {
      final recorder = _RecordingLoadSchedulesByDateUseCase();
      final useCase = LoadSchedulesForWeekUseCase(recorder);

      await useCase(DateTime(2026, 5, 14));

      expect(recorder.calls, [(DateTime(2026, 5, 11), DateTime(2026, 5, 18))]);
    },
  );

  test(
    'GetAdjacentSchedulesWithPreparationUseCase returns closest previous and next schedules',
    () async {
      final selected = DateTime(2026, 5, 15, 12);
      final current = _schedule('current', DateTime(2026, 5, 15, 13));
      final previousClosest = _schedule(
        'previous-close',
        DateTime(2026, 5, 15, 11, 30),
      );
      final previousFar = _schedule('previous-far', DateTime(2026, 5, 15, 9));
      final nextClosest = _schedule(
        'next-close',
        DateTime(2026, 5, 15, 12, 15),
      );
      final nextFar = _schedule('next-far', DateTime(2026, 5, 15, 16));
      final useCase = GetAdjacentSchedulesWithPreparationUseCase(
        _FakeGetSchedulesByDateUseCase([
          nextFar,
          previousFar,
          current,
          nextClosest,
          previousClosest,
        ]),
        _FakeGetPreparationByScheduleIdUseCase({
          previousClosest.id: _preparation('prev-step'),
          nextClosest.id: _preparation('next-step'),
          nextFar.id: _preparation('next-far-step'),
          previousFar.id: _preparation('previous-far-step'),
        }),
      );

      final result = await useCase(
        selectedDateTime: selected,
        currentScheduleId: current.id,
        startDate: DateTime(2026, 5, 15),
        endDate: DateTime(2026, 5, 16),
      );

      expect(result.hasPrevious, isTrue);
      expect(result.hasNext, isTrue);
      expect(result.previousSchedule!.id, 'previous-close');
      expect(result.nextSchedule!.id, 'next-close');
      expect(
        result.previousSchedule!.preparation.preparationStepList.single.id,
        'prev-step',
      );
      expect(
        result.nextSchedule!.preparation.preparationStepList.single.id,
        'next-step',
      );
    },
  );

  test(
    'GetAdjacentSchedulesWithPreparationUseCase omits schedules whose preparation is unavailable',
    () async {
      final selected = DateTime(2026, 5, 15, 12);
      final useCase = GetAdjacentSchedulesWithPreparationUseCase(
        _FakeGetSchedulesByDateUseCase([
          _schedule('previous', DateTime(2026, 5, 15, 11)),
          _schedule('next', DateTime(2026, 5, 15, 13)),
        ]),
        _FakeGetPreparationByScheduleIdUseCase(const {}),
      );

      final result = await useCase(
        selectedDateTime: selected,
        startDate: DateTime(2026, 5, 15),
        endDate: DateTime(2026, 5, 16),
      );

      expect(result, isA<AdjacentSchedulesWithPreparationEntity>());
      expect(result.isEmpty, isTrue);
    },
  );
}

ScheduleEntity _schedule(String id, DateTime scheduleTime) {
  return ScheduleEntity(
    id: id,
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: id,
    scheduleTime: scheduleTime,
    moveTime: const Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: null,
    scheduleNote: '',
  );
}

class _RecordingLoadSchedulesByDateUseCase
    implements LoadSchedulesByDateUseCase {
  final calls = <(DateTime, DateTime?)>[];

  @override
  Future<void> call(DateTime startDate, DateTime? endDate) async {
    calls.add((startDate, endDate));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleRepository implements ScheduleRepository {
  final loadedRanges = <(DateTime, DateTime?)>[];
  final watchedRanges = <(DateTime, DateTime)>[];
  List<ScheduleEntity> watchResult = const [];

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream {
    throw StateError('Use watchSchedulesByDate for range schedule streams.');
  }

  @override
  Stream<List<ScheduleEntity>> watchSchedulesByDate(
    DateTime startDate,
    DateTime endDate,
  ) {
    watchedRanges.add((startDate, endDate));
    return Stream.value(watchResult);
  }

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    loadedRanges.add((startDate, endDate));
    return const [];
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PreparationEntity _preparation(String stepId) {
  return PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: stepId,
        preparationName: stepId,
        preparationTime: const Duration(minutes: 5),
      ),
    ],
  );
}

class _FakeGetSchedulesByDateUseCase extends GetSchedulesByDateUseCase {
  _FakeGetSchedulesByDateUseCase(this.schedules)
    : super(_FakeScheduleRepository());

  final List<ScheduleEntity> schedules;

  @override
  Stream<List<ScheduleEntity>> call(
    DateTime startDate,
    DateTime endDate,
  ) async* {
    yield schedules;
  }
}

class _FakeGetPreparationByScheduleIdUseCase
    extends GetPreparationByScheduleIdUseCase {
  _FakeGetPreparationByScheduleIdUseCase(this.preparations)
    : super(_FakePreparationRepository());

  final Map<String, PreparationEntity> preparations;

  @override
  Future<PreparationEntity> call(String scheduleId) async {
    final preparation = preparations[scheduleId];
    if (preparation == null) {
      throw StateError('Missing preparation for $scheduleId');
    }
    return preparation;
  }
}

class _FakePreparationRepository implements PreparationRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
