import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:on_time_front/presentation/home/screens/home_screen_tmp.dart';
import 'package:on_time_front/presentation/home/utils/home_schedule_card_selection.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';
import '../../helpers/c08_home_query_fixture.dart';

final _now = DateTime(2030, 1, 2, 9);

class _Bloc extends Fake implements ScheduleBloc {
  _Bloc(this.state);
  @override
  ScheduleState state;
  final updates = StreamController<ScheduleState>.broadcast();
  final events = <ScheduleEvent>[];
  @override
  Stream<ScheduleState> get stream => updates.stream;
  @override
  void add(ScheduleEvent event) => events.add(event);
  void update(ScheduleState value) {
    state = value;
    updates.add(value);
  }
}

ScheduleWithPreparationEntity _appointment({
  String id = 'next-week',
  DateTime? instant,
  bool active = false,
}) => ScheduleWithPreparationEntity(
  id: id,
  place: const PlaceEntity(id: 'place', placeName: 'Synthetic place'),
  scheduleName: id,
  scheduleTime: (instant ?? _now.add(const Duration(days: 7))).toUtc(),
  timeZoneId: 'UTC',
  occurrenceOffsetSeconds: 0,
  moveTime: Duration.zero,
  scheduleSpareTime: Duration.zero,
  isChanged: false,
  isStarted: active,
  preparationFrozen: active,
  startedAt: active ? _now.subtract(const Duration(hours: 1)).toUtc() : null,
  scheduleNote: '',
  preparation: const PreparationWithTimeEntity(preparationStepList: []),
);

Future<GoRouter> _mount(
  WidgetTester tester,
  _Bloc bloc, {
  String locale = 'en',
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(bloc.updates.close);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => Scaffold(
          body: HomeScreenContent(
            state: const MonthlySchedulesState(),
            userScore: 80,
            now: _now,
          ),
        ),
      ),
      GoRoute(
        path: '/scheduleStart',
        builder: (_, state) => Scaffold(
          body: Text('Start route:${(state.extra as Map?)?['promptVariant']}'),
        ),
      ),
      GoRoute(
        path: '/alarmScreen',
        builder: (_, _) => const Scaffold(body: Text('Active route')),
      ),
      GoRoute(
        path: '/calendar',
        builder: (_, _) => const Scaffold(body: Text('Calendar route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<ScheduleBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: router,
        theme: themeData,
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.ttf'));
    }
    await fonts.load();
  });
  testWidgets(
    'fresh next-week appointment has one Next card, fixed resolution and explicit start route',
    (tester) async {
      final schedule = _appointment();
      final verified = homeVerifiedValue(schedule);
      // A UI result is independent of the compatibility ScheduleStatus field.
      final bloc = _Bloc(
        const ScheduleState.initial().copyWith(
          nearestQuery: NearestQueryReady(value: verified),
        ),
      );
      final router = await _mount(tester, bloc);
      expect(find.text('Next appointment'), findsOneWidget);
      expect(find.text("Today's Appointments"), findsNothing);
      expect(find.byType(TodaysScheduleTile), findsOneWidget);
      expect(
        tester
            .widget<ScheduleZonedTime>(find.byType(ScheduleZonedTime))
            .resolution,
        same(verified.resolution),
      );
      await _tap(tester, const Key('today_schedule_tile'));
      expect(router.routeInformationProvider.value.uri.path, '/scheduleStart');
      expect(find.text('Start route:earlyStart'), findsOneWidget);
      expect(bloc.events.whereType<ScheduleStarted>(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'fresh today appointment has only Today, not a duplicate Next card',
    (tester) async {
      final bloc = _Bloc(
        homeReadyState(
          _appointment(instant: _now.add(const Duration(hours: 2))),
        ),
      );
      await _mount(tester, bloc);
      expect(find.text("Today's Appointments"), findsOneWidget);
      expect(find.text('Next appointment'), findsNothing);
      expect(find.byType(TodaysScheduleTile), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  final stale = homeVerifiedValue(_appointment());
  final incomplete = <String, NearestScheduleQuery>{
    'loading': NearestQueryLoading(
      key: homeQueryKey,
      progress: homeQueryProgress,
      stale: stale,
    ),
    'error': NearestQueryError(
      key: homeQueryKey,
      reason: NearestQueryFailureReason.preparationMissing,
      stale: stale,
    ),
    'interrupted': NearestQueryLimited(
      key: homeQueryKey,
      reason: NearestQueryLimitReason.interrupted,
      progress: homeQueryProgress,
      canContinue: true,
      canRetry: false,
      stale: stale,
    ),
  };
  for (final entry in incomplete.entries) {
    testWidgets(
      '${entry.key} keeps previous details read-only and sends the displayed query key',
      (tester) async {
        final bloc = _Bloc(
          const ScheduleState.initial().copyWith(nearestQuery: entry.value),
        );
        final router = await _mount(tester, bloc, scale: 2.5);
        expect(find.text('Previously checked appointment'), findsOneWidget);
        expect(find.text('Next appointment'), findsNothing);
        final tile = tester.widget<TodaysScheduleTile>(
          find.byType(TodaysScheduleTile),
        );
        expect(tile.schedule?.id, 'next-week');
        expect(tile.onTap, isNull);
        final action = switch (entry.key) {
          'loading' => const Key('cancel-nearest-query'),
          'error' => const Key('retry-upcoming-schedule'),
          _ => const Key('continue-nearest-query'),
        };
        await _tap(tester, action);
        final event = bloc.events.single;
        final sentKey = switch (event) {
          ScheduleNearestQueryCancelRequested() => event.queryKey,
          ScheduleNearestQueryRetryRequested() => event.queryKey,
          ScheduleNearestQueryContinueRequested() => event.queryKey,
          _ => null,
        };
        expect(sentKey, homeQueryKey);
        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'only a complete Empty result claims there are no upcoming appointments',
    (tester) async {
      final bloc = _Bloc(const ScheduleState.initial());
      await _mount(tester, bloc);
      for (final query in <NearestScheduleQuery>[
        const NearestQueryIdle(),
        const NearestQueryLoading(
          key: homeQueryKey,
          progress: homeQueryProgress,
        ),
        const NearestQueryError(
          key: homeQueryKey,
          reason: NearestQueryFailureReason.storeReadFailed,
        ),
        const NearestQueryLimited(
          key: homeQueryKey,
          reason: NearestQueryLimitReason.searchBudgetExhausted,
          progress: homeQueryProgress,
          canContinue: false,
          canRetry: false,
        ),
      ]) {
        bloc.update(
          const ScheduleState.initial().copyWith(nearestQuery: query),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TodaysScheduleTile), findsNothing);
        expect(find.text('No upcoming appointments.'), findsNothing);
        expect(find.text('No appointments today'), findsNothing);
      }
      bloc.update(homeEmptyState());
      await tester.pumpAndSettle();
      expect(find.text('No upcoming appointments.'), findsOneWidget);
      expect(
        tester
            .widget<TodaysScheduleTile>(find.byType(TodaysScheduleTile))
            .onTap,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'terminal budget limit exposes Calendar but no retry or continue loophole at large Korean text',
    (tester) async {
      final bloc = _Bloc(
        const ScheduleState.initial().copyWith(
          nearestQuery: const NearestQueryLimited(
            key: homeQueryKey,
            reason: NearestQueryLimitReason.searchBudgetExhausted,
            progress: homeQueryProgress,
            canContinue: false,
            canRetry: false,
          ),
        ),
      );
      final router = await _mount(tester, bloc, locale: 'ko', scale: 2.5);
      expect(find.byKey(const Key('retry-upcoming-schedule')), findsNothing);
      expect(find.byKey(const Key('continue-nearest-query')), findsNothing);
      await _tap(tester, const Key('nearest-query-calendar'));
      expect(router.routeInformationProvider.value.uri.path, '/calendar');
      expect(bloc.events, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'durable active and explicit notification owners survive every query state',
    () {
      final active = _appointment(
        id: 'active',
        instant: _now.subtract(const Duration(days: 1)),
        active: true,
      );
      final prompt = _appointment(id: 'prompt');
      for (final query in <NearestScheduleQuery>[
        const NearestQueryIdle(),
        ...incomplete.values,
        NearestQueryReady(value: stale),
        NearestQueryEmpty(authority: homeQueryAuthority()),
      ]) {
        final activeState = ScheduleState.started(
          active,
          isResumedPreparation: true,
        ).copyWith(nearestQuery: query);
        expect(
          HomeScheduleCardSelection.at(activeState, _now).schedule?.id,
          'active',
        );
        expect(
          HomeScheduleCardSelection.at(activeState, _now).isActive,
          isTrue,
        );
        final promptState = ScheduleState.upcoming(
          prompt,
          notificationPromptOwner: Object(),
        ).copyWith(nearestQuery: query);
        final selection = HomeScheduleCardSelection.at(promptState, _now);
        expect(selection.schedule?.id, 'prompt');
        expect(selection.kind, HomeScheduleCardKind.prompt);
      }
      expect(
        HomeScheduleCardSelection.at(
          ScheduleState.started(prompt),
          _now,
        ).schedule,
        isNull,
      );
    },
  );

  testWidgets(
    'active preparation stays actionable while query cancellation only targets the query',
    (tester) async {
      final active = _appointment(
        id: 'active',
        instant: _now.subtract(const Duration(days: 1)),
        active: true,
      );
      final bloc = _Bloc(
        ScheduleState.started(
          active,
          isResumedPreparation: true,
        ).copyWith(nearestQuery: incomplete['loading']),
      );
      final router = await _mount(tester, bloc);
      expect(find.text('Preparation in progress'), findsOneWidget);
      expect(
        find.textContaining('These are previously checked details'),
        findsNothing,
      );
      expect(
        tester
            .widget<TodaysScheduleTile>(find.byType(TodaysScheduleTile))
            .schedule
            ?.id,
        'active',
      );
      await _tap(tester, const Key('cancel-nearest-query'));
      expect(bloc.events.single, isA<ScheduleNearestQueryCancelRequested>());
      await _tap(tester, const Key('today_schedule_tile'));
      expect(router.routeInformationProvider.value.uri.path, '/alarmScreen');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a callback retained from an older query sends its old key, never the replacement key',
    (tester) async {
      final bloc = _Bloc(
        const ScheduleState.initial().copyWith(
          nearestQuery: incomplete['error'],
        ),
      );
      await _mount(tester, bloc);
      final oldAction = tester
          .widget<TextButton>(find.byKey(const Key('retry-upcoming-schedule')))
          .onPressed!;
      const replacement = NearestQueryKey(generation: 8, epoch: 3, revision: 6);
      bloc.update(
        const ScheduleState.initial().copyWith(
          nearestQuery: const NearestQueryError(
            key: replacement,
            reason: NearestQueryFailureReason.storeReadFailed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TodaysScheduleTile), findsNothing);
      oldAction();
      expect(
        (bloc.events.single as ScheduleNearestQueryRetryRequested).queryKey,
        homeQueryKey,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a resolved next appointment still exposes other time issues for calendar review',
    (tester) async {
      final bloc = _Bloc(
        homeReadyState(_appointment()).copyWith(
          nearestQuery: NearestQueryReady(
            value: stale,
            issues: const [
              NearestQueryIssue(
                reason: NearestQueryIssueReason.unknownTimeZone,
                scheduleId: 'needs-review',
              ),
            ],
          ),
        ),
      );
      final router = await _mount(tester, bloc);
      expect(find.text('Next appointment'), findsOneWidget);
      expect(
        find.textContaining('Some appointment times need review'),
        findsOneWidget,
      );
      await _tap(tester, const Key('nearest-query-calendar'));
      expect(router.routeInformationProvider.value.uri.path, '/calendar');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
