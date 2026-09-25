import '../../helpers/c08_home_query_fixture.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/device_civil_day.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/components/device_day_refresh.dart';
import 'package:on_time_front/presentation/home/components/month_calendar.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:on_time_front/presentation/home/screens/home_screen_tmp.dart';
import 'package:on_time_front/presentation/home/utils/home_schedule_card_selection.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:table_calendar/table_calendar.dart';

class _ScheduleBloc extends Fake implements ScheduleBloc {
  _ScheduleBloc(this.state, {this.updates});
  final StreamController<ScheduleState>? updates;
  final events = <ScheduleEvent>[];
  @override
  void add(ScheduleEvent event) => events.add(event);
  @override
  ScheduleState state;
  @override
  Stream<ScheduleState> get stream => updates?.stream ?? const Stream.empty();
}

ScheduleWithPreparationEntity _appointment(
  DateTime instant, {
  bool active = false,
  bool frozenOnly = false,
  bool retained = false,
  ScheduleDoneStatus done = ScheduleDoneStatus.notEnded,
}) => ScheduleWithPreparationEntity(
  id: 'appointment',
  place: const PlaceEntity(id: 'place', placeName: 'Office'),
  scheduleName: 'Original appointment',
  scheduleTime: instant.toUtc(),
  timeZoneId: 'UTC',
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  isChanged: false,
  isStarted: active,
  startedAt: active ? instant.subtract(const Duration(minutes: 10)) : null,
  preparationFrozen: active || frozenOnly,
  retainedRecurringReference: retained,
  doneStatus: done,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
  preparation: const PreparationWithTimeEntity(preparationStepList: []),
);

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  theme: themeData,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  final now = DateTime(2030, 1, 1, 12);
  final day = DeviceCivilDay.at(now);

  test(
    'today classification uses the device half-open day independently of next appointment',
    () {
      for (final (instant, visible) in [
        (day.startUtc.subtract(const Duration(microseconds: 1)), false),
        (day.startUtc, true),
        (day.endUtc.subtract(const Duration(microseconds: 1)), true),
        (day.endUtc, false),
      ]) {
        final selected = HomeScheduleCardSelection.at(
          homeReadyState(_appointment(instant)),
          now,
        );
        expect(selected.kind == HomeScheduleCardKind.today, visible);
        expect(selected.isActive, isFalse);
      }
    },
  );

  test('only durable incomplete runs retain a card outside today', () {
    final yesterday = day.startUtc.subtract(const Duration(hours: 2));
    final tomorrow = day.endUtc.add(const Duration(hours: 2));
    for (final instant in [yesterday, tomorrow]) {
      expect(
        HomeScheduleCardSelection.at(
          ScheduleState.started(_appointment(instant, active: true)),
          now,
        ).isActive,
        isTrue,
      );
      expect(
        HomeScheduleCardSelection.at(
          ScheduleState.started(_appointment(instant, frozenOnly: true)),
          now,
        ).schedule,
        isNull,
      );
      expect(
        HomeScheduleCardSelection.at(
          ScheduleState.started(
            _appointment(
              instant,
              active: true,
              done: ScheduleDoneStatus.normalEnd,
            ),
          ),
          now,
        ).schedule,
        isNull,
      );
    }
  });

  test(
    'a closed recurring reference retains only its incomplete durable run card',
    () {
      for (final active in [false, true]) {
        for (final done in [
          ScheduleDoneStatus.notEnded,
          ScheduleDoneStatus.normalEnd,
        ]) {
          final selected = HomeScheduleCardSelection.at(
            ScheduleState.started(
              _appointment(
                now.toUtc(),
                active: active,
                retained: true,
                done: done,
              ),
            ),
            now,
          );
          expect(
            selected.schedule != null,
            active && done == ScheduleDoneStatus.notEnded,
          );
          expect(
            selected.isActive,
            active && done == ScheduleDoneStatus.notEnded,
          );
        }
      }
    },
  );

  testWidgets(
    'actual home displays a tomorrow recommendation as Next appointment',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          BlocProvider<ScheduleBloc>.value(
            value: _ScheduleBloc(homeReadyState(_appointment(day.endUtc))),
            child: HomeScreenContent(
              state: const MonthlySchedulesState(),
              userScore: 80,
              now: now,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<TodaysScheduleTile>(
              find.byKey(const Key('today_schedule_tile')),
            )
            .schedule
            ?.id,
        'appointment',
      );
      expect(find.text('Original appointment'), findsOneWidget);
      expect(find.text('Next appointment'), findsOneWidget);
      expect(find.text("Today's Appointments"), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'actual home content labels a previous-day durable run as in progress',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          BlocProvider<ScheduleBloc>.value(
            value: _ScheduleBloc(
              ScheduleState.started(
                _appointment(
                  day.startUtc.subtract(const Duration(hours: 1)),
                  active: true,
                ),
              ),
            ),
            child: HomeScreenContent(
              state: const MonthlySchedulesState(),
              userScore: 80,
              now: now,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Preparation in progress'), findsOneWidget);
      expect(
        tester
            .widget<TodaysScheduleTile>(
              find.byKey(const Key('today_schedule_tile')),
            )
            .onTap,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'device-day observer refreshes at midnight and resume and disposes timers',
    (tester) async {
      var current = DateTime(2030, 1, 1, 23, 59, 59);
      final observed = <DateTime>[];
      await tester.pumpWidget(
        _app(
          DeviceDayRefresh(
            now: () => current,
            builder: (context, date) {
              observed.add(date);
              return Text('${date.day}');
            },
          ),
        ),
      );
      current = DateTime(2030, 1, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      current = DateTime(2030, 1, 5, 12);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      final count = observed.length;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(days: 2));
      expect(observed, hasLength(count));
    },
  );

  testWidgets(
    'calendar follows the new today month only before manual navigation',
    (tester) async {
      Widget calendar(DateTime today) => _app(
        MonthCalendar(
          monthlySchedulesState: const MonthlySchedulesState(),
          dispatchBlocEvents: false,
          today: today,
        ),
      );
      await tester.pumpWidget(calendar(DateTime(2030, 1, 31)));
      await tester.pump();
      await tester.pumpWidget(calendar(DateTime(2030, 2, 1)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TableCalendar>(find.byType(TableCalendar))
            .focusedDay
            .month,
        2,
      );
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TableCalendar>(find.byType(TableCalendar))
            .focusedDay
            .month,
        1,
      );
      await tester.pumpWidget(calendar(DateTime(2030, 3, 1)));
      await tester.pumpAndSettle();
      final value = tester.widget<TableCalendar>(find.byType(TableCalendar));
      expect(value.focusedDay.month, 1);
      expect(value.currentDay?.month, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final active in [false, true]) {
    testWidgets(
      'read failure preserves the visible card and retry; active=$active',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final appointment = _appointment(
          active
              ? day.startUtc.subtract(const Duration(hours: 1))
              : now.toUtc().add(const Duration(hours: 1)),
          active: active,
        );
        final bloc = _ScheduleBloc(
          (active
                  ? ScheduleState.started(
                      appointment,
                      isResumedPreparation: true,
                    )
                  : homeReadyState(appointment))
              .copyWith(
                nearestQuery: NearestQueryError(
                  key: homeQueryKey,
                  reason: NearestQueryFailureReason.storeReadFailed,
                  stale: homeVerifiedValue(appointment),
                ),
              ),
        );
        await tester.pumpWidget(
          _app(
            BlocProvider<ScheduleBloc>.value(
              value: bloc,
              child: HomeScreenContent(
                state: const MonthlySchedulesState(),
                userScore: 80,
                now: now,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Original appointment'), findsOneWidget);
        expect(
          find.text('Could not check appointments. Please try again.'),
          findsOneWidget,
        );
        final tile = tester.widget<TodaysScheduleTile>(
          find.byKey(const Key('today_schedule_tile')),
        );
        expect(tile.onTap != null, active);
        await tester.tap(
          find.byKey(const Key('retry-upcoming-schedule')).hitTestable(),
        );
        await tester.pump();
        expect(
          bloc.events.whereType<ScheduleNearestQueryRetryRequested>(),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        final scroll = find.byKey(const Key('home-content-scroll'));
        final calendar = find.byKey(const Key('home_month_calendar'));
        final scrollable = find
            .descendant(of: scroll, matching: find.byType(Scrollable))
            .first;
        // The naturally sized card can put the lazy calendar beyond cache.
        await tester.scrollUntilVisible(calendar, 100, scrollable: scrollable);
        await tester.pumpAndSettle();
        final calendarBefore = tester.getSize(calendar);
        final revealedOffset = tester
            .state<ScrollableState>(scrollable)
            .position
            .pixels;
        await tester.drag(scroll, const Offset(0, 100));
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          lessThan(revealedOffset),
        );
        expect(tester.getSize(calendar), calendarBefore);
        await tester.drag(scroll, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(calendar).dy,
          lessThanOrEqualTo(568 + 0.001),
        );
        expect(tester.getSize(calendar), calendarBefore);
        await tester.scrollUntilVisible(
          find.byKey(const Key('retry-upcoming-schedule')),
          -100,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('retry-upcoming-schedule')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'initial read failure offers retry without claiming there are no appointments',
    (tester) async {
      final bloc = _ScheduleBloc(
        (const ScheduleState.initial()).copyWith(
          nearestQuery: const NearestQueryError(
            key: homeQueryKey,
            reason: NearestQueryFailureReason.storeReadFailed,
          ),
        ),
      );
      await tester.pumpWidget(
        _app(
          BlocProvider<ScheduleBloc>.value(
            value: bloc,
            child: HomeScreenContent(
              state: const MonthlySchedulesState(),
              userScore: 80,
              now: now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TodaysScheduleTile), findsNothing);
      await tester.tap(
        find.byKey(const Key('retry-upcoming-schedule')).hitTestable(),
      );
      await tester.pump();
      expect(
        bloc.events.whereType<ScheduleNearestQueryRetryRequested>(),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'actual home listener does not navigate when an existing durable run is restored',
    (tester) async {
      final updates = StreamController<ScheduleState>.broadcast();
      addTearDown(updates.close);
      final bloc = _ScheduleBloc(
        const ScheduleState.initial(),
        updates: updates,
      );
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: BlocProvider<ScheduleBloc>.value(
                value: bloc,
                child: HomeScreenContent(
                  state: const MonthlySchedulesState(),
                  userScore: 80,
                  now: now,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/scheduleStart',
            builder: (context, state) =>
                const Scaffold(body: Text('Unexpected navigation')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          theme: themeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      final restored = ScheduleState.started(
        _appointment(
          day.startUtc.subtract(const Duration(hours: 1)),
          active: true,
        ),
        isResumedPreparation: true,
      );
      bloc.state = restored;
      updates.add(restored);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.text('Unexpected navigation'), findsNothing);
      expect(find.text('Preparation in progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
