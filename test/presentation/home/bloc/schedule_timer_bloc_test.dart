import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/home/bloc/schedule_timer_bloc.dart';

void main() {
  test('started with a past schedule immediately finishes', () async {
    final bloc = ScheduleTimerBloc();
    addTearDown(bloc.close);
    final scheduleTime = DateTime.now().subtract(const Duration(minutes: 1));

    bloc.add(ScheduleTimerStarted(scheduleTime));

    await expectLater(
      bloc.stream,
      emits(
        isA<ScheduleTimerFinished>().having(
          (state) => state.scheduleTime,
          'scheduleTime',
          scheduleTime,
        ),
      ),
    );
  });

  test(
    'tick before the schedule keeps timer running with remaining duration',
    () async {
      final bloc = ScheduleTimerBloc();
      addTearDown(bloc.close);
      final scheduleTime = DateTime.now().add(const Duration(hours: 1));
      final tickTime = scheduleTime.subtract(const Duration(minutes: 10));

      bloc.add(ScheduleTimerStarted(scheduleTime));
      await expectLater(bloc.stream, emits(isA<ScheduleTimerRunning>()));

      bloc.add(ScheduleTimerTicked(tickTime));

      await expectLater(
        bloc.stream,
        emits(
          isA<ScheduleTimerRunning>()
              .having(
                (state) => state.scheduleTime,
                'scheduleTime',
                scheduleTime,
              )
              .having((state) => state.currentTime, 'currentTime', tickTime)
              .having(
                (state) => state.remainingDuration,
                'remainingDuration',
                const Duration(minutes: 10),
              ),
        ),
      );
    },
  );

  test(
    'tick at the schedule time finishes and preserves target schedule',
    () async {
      final bloc = ScheduleTimerBloc();
      addTearDown(bloc.close);
      final scheduleTime = DateTime.now().add(const Duration(hours: 1));

      bloc.add(ScheduleTimerStarted(scheduleTime));
      await expectLater(bloc.stream, emits(isA<ScheduleTimerRunning>()));

      bloc.add(ScheduleTimerTicked(scheduleTime));

      await expectLater(
        bloc.stream,
        emits(
          isA<ScheduleTimerFinished>().having(
            (state) => state.scheduleTime,
            'scheduleTime',
            scheduleTime,
          ),
        ),
      );
    },
  );

  test('stopped returns to initial and ignores later ticks', () async {
    final bloc = ScheduleTimerBloc();
    addTearDown(bloc.close);
    final scheduleTime = DateTime.now().add(const Duration(hours: 1));

    bloc.add(ScheduleTimerStarted(scheduleTime));
    await expectLater(bloc.stream, emits(isA<ScheduleTimerRunning>()));

    bloc.add(const ScheduleTimerStopped());

    await expectLater(bloc.stream, emits(const ScheduleTimerInitial()));

    bloc.add(ScheduleTimerTicked(scheduleTime));
    await pumpEventQueue();

    expect(bloc.state, const ScheduleTimerInitial());
  });

  test('updated with null clears the active timer', () async {
    final bloc = ScheduleTimerBloc();
    addTearDown(bloc.close);
    final scheduleTime = DateTime.now().add(const Duration(hours: 1));

    bloc.add(ScheduleTimerStarted(scheduleTime));
    await expectLater(bloc.stream, emits(isA<ScheduleTimerRunning>()));

    bloc.add(const ScheduleTimerUpdated(null));

    await expectLater(bloc.stream, emits(const ScheduleTimerInitial()));
  });

  test('updated with a schedule starts a new timer', () async {
    final bloc = ScheduleTimerBloc();
    addTearDown(bloc.close);
    final scheduleTime = DateTime.now().add(const Duration(hours: 1));

    bloc.add(ScheduleTimerUpdated(scheduleTime));

    await expectLater(
      bloc.stream,
      emits(
        isA<ScheduleTimerRunning>().having(
          (state) => state.scheduleTime,
          'scheduleTime',
          scheduleTime,
        ),
      ),
    );
  });

}
