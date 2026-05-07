import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/alarm/screens/schedule_start_screen.dart';
import 'package:on_time_front/presentation/shared/router/route_arguments.dart';

void main() {
  group('calendar route arguments', () {
    test('prefers DateTime extra and falls back to query parameters', () {
      final extraDate = DateTime(2026, 5, 7);
      final queryDate = DateTime(2026, 5, 8);

      expect(
        parseCalendarInitialDate(
          extra: extraDate,
          queryParameters: {'date': queryDate.toIso8601String()},
        ),
        extraDate,
      );
      expect(
        parseCalendarInitialDate(
          queryParameters: {'date': queryDate.toIso8601String()},
        ),
        queryDate,
      );
      expect(parseCalendarInitialDate(extra: 'not-a-date'), isNull);
    });

    testWidgets('router does not throw for malformed calendar extras',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/calendar',
        routes: [
          GoRoute(
            path: '/calendar',
            builder: (context, state) {
              final date = calendarInitialDateFromState(state);
              return Material(
                child: Text(date?.toIso8601String() ?? 'NO_DATE'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/calendar', extra: 'not-a-date');
      await tester.pumpAndSettle();

      expect(find.text('NO_DATE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('router reads durable calendar query parameter',
        (tester) async {
      final router = GoRouter(
        initialLocation: calendarRouteLocation(DateTime(2026, 5, 7)),
        routes: [
          GoRoute(
            path: '/calendar',
            builder: (context, state) {
              final date = calendarInitialDateFromState(state);
              return Material(child: Text('${date?.year}-${date?.month}'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('2026-5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('scheduleStart route arguments', () {
    test('rejects non-map extras and accepts string-keyed legacy maps', () {
      expect(routeExtraMap('bad-extra'), isNull);
      expect(
        routeExtraMap(<String, Object?>{'scheduleId': 'schedule-1'}),
        {'scheduleId': 'schedule-1'},
      );
      expect(routeExtraMap(<Object, Object>{1: 'bad-key'}), isNull);
    });

    test('prompt helpers ignore malformed optional fields', () {
      expect(
        scheduleStartPromptVariantFromRouteExtra(
          const {'isFiveMinutesBefore': 'definitely'},
        ),
        ScheduleStartPromptVariant.officialStart,
      );
      expect(
        scheduleStartPromptVariantFromRouteExtra(
          const {'promptVariant': 1},
        ),
        ScheduleStartPromptVariant.officialStart,
      );
      expect(
        scheduleStartLaunchActionFromRouteExtra(
          const {'alarmLaunchAction': false},
        ),
        ScheduleStartLaunchAction.prompt,
      );
    });

    testWidgets('router treats malformed scheduleStart extra as absent',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/scheduleStart',
        routes: [
          GoRoute(
            path: '/scheduleStart',
            builder: (context, state) {
              final extra = scheduleStartRouteExtraFromState(state);
              return Material(
                child: Text(extra == null ? 'NO_EXTRA' : 'HAS_EXTRA'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/scheduleStart', extra: 'bad-extra');
      await tester.pumpAndSettle();

      expect(find.text('NO_EXTRA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('earlyLate route arguments', () {
    test('parses extras and durable query parameters', () {
      final extraArguments = parseEarlyLateRouteArguments(
        extra: const {'earlyLateTime': 45, 'isLate': false},
      );
      final queryArguments = parseEarlyLateRouteArguments(
        queryParameters: const {'earlyLateTime': '-30', 'isLate': 'true'},
      );

      expect(extraArguments?.earlyLateTime, 45);
      expect(extraArguments?.isLate, isFalse);
      expect(queryArguments?.earlyLateTime, -30);
      expect(queryArguments?.isLate, isTrue);
    });

    test('rejects missing and wrong-type required values', () {
      expect(parseEarlyLateRouteArguments(), isNull);
      expect(
        parseEarlyLateRouteArguments(
          extra: const {
            'earlyLateTime': <int>[1],
            'isLate': false
          },
        ),
        isNull,
      );
      expect(
        parseEarlyLateRouteArguments(
          extra: const {
            'earlyLateTime': 1,
            'isLate': <bool>[true]
          },
        ),
        isNull,
      );
    });

    testWidgets('router redirects missing and malformed earlyLate args home',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/earlyLate',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
          GoRoute(
            path: '/earlyLate',
            redirect: (context, state) {
              return earlyLateRouteArgumentsFromState(state) == null
                  ? '/home'
                  : null;
            },
            builder: (context, state) {
              final args = earlyLateRouteArgumentsFromState(state)!;
              return Text('EARLY_LATE:${args.earlyLateTime}:${args.isLate}');
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(tester.takeException(), isNull);

      router.go('/earlyLate', extra: 'bad-extra');
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('router accepts valid earlyLate query arguments',
        (tester) async {
      final router = GoRouter(
        initialLocation: earlyLateRouteLocation(
          earlyLateTime: 90,
          isLate: true,
        ),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
          GoRoute(
            path: '/earlyLate',
            redirect: (context, state) {
              return earlyLateRouteArgumentsFromState(state) == null
                  ? '/home'
                  : null;
            },
            builder: (context, state) {
              final args = earlyLateRouteArgumentsFromState(state)!;
              return Text('EARLY_LATE:${args.earlyLateTime}:${args.isLate}');
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('EARLY_LATE:90:true'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
