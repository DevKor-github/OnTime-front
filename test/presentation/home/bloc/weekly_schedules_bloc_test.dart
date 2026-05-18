import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_week_use_case.dart';
import 'package:on_time_front/presentation/home/bloc/weekly_schedules_bloc.dart';

class StubLoadSchedulesForWeekUseCase implements LoadSchedulesForWeekUseCase {
  StubLoadSchedulesForWeekUseCase(this.handler);
  final Future<void> Function(DateTime date) handler;

  @override
  Future<void> call(DateTime date) => handler(date);
}

class StubGetSchedulesByDateUseCase implements GetSchedulesByDateUseCase {
  StubGetSchedulesByDateUseCase([this.schedules = const []]);

  final List<ScheduleEntity> schedules;
  final calls = <(DateTime, DateTime)>[];

  @override
  Stream<List<ScheduleEntity>> call(DateTime startDate, DateTime endDate) {
    calls.add((startDate, endDate));
    return Stream.value(schedules);
  }
}

void main() {
  test('state exposes schedule dates, today schedule, and copy updates', () {
    final now = DateTime.now();
    final laterToday = _schedule(
      id: 'later',
      scheduleTime: DateTime(now.year, now.month, now.day, 18),
    );
    final earlierToday = _schedule(
      id: 'earlier',
      scheduleTime: DateTime(now.year, now.month, now.day, 9),
    );
    final endedToday = _schedule(
      id: 'ended',
      scheduleTime: DateTime(now.year, now.month, now.day, 8),
      doneStatus: ScheduleDoneStatus.normalEnd,
    );
    final tomorrow = _schedule(
      id: 'tomorrow',
      scheduleTime: DateTime(now.year, now.month, now.day + 1, 9),
    );

    final state = WeeklySchedulesState(
      status: WeeklySchedulesStatus.success,
      schedules: [laterToday, endedToday, tomorrow, earlierToday],
    );

    expect(state.dates, [
      laterToday.scheduleTime,
      endedToday.scheduleTime,
      tomorrow.scheduleTime,
      earlierToday.scheduleTime,
    ]);
    expect(state.todaySchedule, earlierToday);
    expect(
      state.copyWith(status: () => WeeklySchedulesStatus.loading).status,
      WeeklySchedulesStatus.loading,
    );
    expect(state.copyWith(schedules: () => [tomorrow]).schedules, [tomorrow]);
    expect(state.props, [
      WeeklySchedulesStatus.success,
      laterToday,
      endedToday,
      tomorrow,
      earlierToday,
    ]);
  });

  test('weekly subscription event derives Monday-to-Monday range', () {
    final event = WeeklySchedulesSubscriptionRequested(
      date: DateTime(2026, 5, 15, 18),
    );

    expect(event.startDate, DateTime(2026, 5, 11, 18));
    expect(event.endDate, DateTime(2026, 5, 18, 18));
    expect(event.props, [DateTime(2026, 5, 11, 18), DateTime(2026, 5, 18, 18)]);
  });

  test('today schedule is null when no not-ended schedule is today', () {
    final now = DateTime.now();
    final state = WeeklySchedulesState(
      schedules: [
        _schedule(
          id: 'ended',
          scheduleTime: DateTime(now.year, now.month, now.day, 8),
          doneStatus: ScheduleDoneStatus.normalEnd,
        ),
        _schedule(
          id: 'tomorrow',
          scheduleTime: DateTime(now.year, now.month, now.day + 1, 9),
        ),
      ],
    );

    expect(state.todaySchedule, isNull);
  });

  test('load failure emits error state instead of throwing', () async {
    final bloc = WeeklySchedulesBloc(
      StubLoadSchedulesForWeekUseCase(
        (_) async => throw Exception('unauthorized'),
      ),
      StubGetSchedulesByDateUseCase(),
    );
    addTearDown(bloc.close);

    bloc.add(WeeklySchedulesSubscriptionRequested(date: DateTime(2026, 5, 5)));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<WeeklySchedulesState>().having(
          (state) => state.status,
          'status',
          WeeklySchedulesStatus.error,
        ),
      ),
    );
  });

  test(
    'successful subscription loads week then emits streamed schedules',
    () async {
      final schedule = _schedule(
        id: 'meeting',
        scheduleTime: DateTime(2026, 5, 12, 9),
      );
      final loadedWeeks = <DateTime>[];
      final getSchedulesByDateUseCase = StubGetSchedulesByDateUseCase([
        schedule,
      ]);
      final bloc = WeeklySchedulesBloc(
        StubLoadSchedulesForWeekUseCase((date) async {
          loadedWeeks.add(date);
        }),
        getSchedulesByDateUseCase,
      );
      addTearDown(bloc.close);

      bloc.add(
        WeeklySchedulesSubscriptionRequested(date: DateTime(2026, 5, 15)),
      );

      final state = await bloc.stream.firstWhere(
        (state) => state.status == WeeklySchedulesStatus.success,
      );

      expect(loadedWeeks, [DateTime(2026, 5, 15)]);
      expect(getSchedulesByDateUseCase.calls.single, (
        DateTime(2026, 5, 11),
        DateTime(2026, 5, 18),
      ));
      expect(state.schedules, [schedule]);
    },
  );
}

ScheduleEntity _schedule({
  required String id,
  required DateTime scheduleTime,
  ScheduleDoneStatus doneStatus = ScheduleDoneStatus.notEnded,
}) {
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
    doneStatus: doneStatus,
  );
}
