import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/components/month_calendar.dart';
import 'package:on_time_front/presentation/shared/components/calendar/centered_calendar_header.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('selecting a day reports the selected calendar date', (
    tester,
  ) async {
    DateTime? selected;
    final targetDate = DateTime.now().add(const Duration(days: 2));

    await tester.pumpWidget(
      _TestApp(
        child: MonthCalendar(
          dispatchBlocEvents: false,
          monthlySchedulesState: const MonthlySchedulesState(
            status: MonthlySchedulesStatus.success,
          ),
          onDateSelected: (date) => selected = date,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(targetDate.day.toString()).last);
    await tester.pumpAndSettle();

    expect(
      selected,
      DateTime(targetDate.year, targetDate.month, targetDate.day),
    );
  });

  testWidgets('scheduled days render without hiding the selected day', (
    tester,
  ) async {
    final scheduledDay = DateTime.now().add(const Duration(days: 3));

    await tester.pumpWidget(
      _TestApp(
        child: MonthCalendar(
          dispatchBlocEvents: false,
          monthlySchedulesState: MonthlySchedulesState(
            status: MonthlySchedulesStatus.success,
            schedules: {
              DateTime(scheduledDay.year, scheduledDay.month, scheduledDay.day):
                  [_schedule(scheduledDay)],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(scheduledDay.day.toString()), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact height clamps calendar rows without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: SizedBox(
          height: 260,
          child: MonthCalendar(
            dispatchBlocEvents: false,
            rowHeight: 80,
            monthlySchedulesState: const MonthlySchedulesState(
              status: MonthlySchedulesStatus.success,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MonthCalendar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header arrows move between months and request month loads', (
    tester,
  ) async {
    final bloc = _RecordingMonthlySchedulesBloc();
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final nextMonth = DateTime(now.year, now.month, 1);

    await tester.pumpWidget(
      _TestApp(
        bloc: bloc,
        child: MonthCalendar(
          monthlySchedulesState: const MonthlySchedulesState(
            status: MonthlySchedulesStatus.success,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byType(CenteredCalendarHeader);
    expect(header, findsOneWidget);

    await tester.tap(
      find.descendant(of: header, matching: find.byType(IconButton)).first,
    );
    await tester.pumpAndSettle();

    expect(
      bloc.addedEvents,
      contains(
        isA<MonthlySchedulesMonthAdded>().having(
          (event) => event.date,
          'date',
          previousMonth,
        ),
      ),
    );

    await tester.tap(
      find.descendant(of: header, matching: find.byType(IconButton)).last,
    );
    await tester.pumpAndSettle();

    expect(
      bloc.addedEvents,
      contains(
        isA<MonthlySchedulesMonthAdded>().having(
          (event) => event.date,
          'date',
          nextMonth,
        ),
      ),
    );
  });

  testWidgets('unbounded vertical layout keeps the configured row height', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: SingleChildScrollView(
          child: MonthCalendar(
            dispatchBlocEvents: false,
            rowHeight: 42,
            monthlySchedulesState: const MonthlySchedulesState(
              status: MonthlySchedulesStatus.success,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MonthCalendar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.bloc});

  final Widget child;
  final MonthlySchedulesBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      theme: themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

    final bloc = this.bloc;
    if (bloc == null) {
      return app;
    }

    return MaterialApp(
      theme: themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<MonthlySchedulesBloc>.value(
        value: bloc,
        child: Scaffold(body: child),
      ),
    );
  }
}

class _RecordingMonthlySchedulesBloc extends Mock
    implements MonthlySchedulesBloc {
  final addedEvents = <MonthlySchedulesEvent>[];

  @override
  void add(MonthlySchedulesEvent event) {
    addedEvents.add(event);
  }

  @override
  MonthlySchedulesState get state =>
      const MonthlySchedulesState(status: MonthlySchedulesStatus.success);

  @override
  Stream<MonthlySchedulesState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

ScheduleEntity _schedule(DateTime date) {
  return ScheduleEntity(
    id: 'schedule-1',
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Meeting',
    scheduleTime: date,
    moveTime: const Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: null,
    scheduleNote: '',
  );
}
