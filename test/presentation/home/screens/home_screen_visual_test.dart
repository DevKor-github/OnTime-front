import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/screens/home_screen_tmp.dart';
import 'package:on_time_front/presentation/shared/components/bottom_nav_bar_scaffold.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../../helpers/visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);

  testWidgets('Home shell matches Figma with a real December date grid', (
    tester,
  ) async {
    await _pumpHomeFixture(tester, MonthlySchedulesStatus.success);

    expect(find.text('5월 12일 오후 6시'), findsOneWidget);
    expect(find.text('2024년 12월'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('home_hero'))),
      const Rect.fromLTWH(0, 0, 390, 230),
    );
    expect(
      tester.getRect(find.byKey(const Key('today_schedule_card'))),
      const Rect.fromLTWH(15, 177, 360, 137),
    );
    expect(
      tester.getRect(find.byKey(const Key('today_background_surface'))),
      const Rect.fromLTWH(0, 230, 390, 84),
    );
    expect(
      tester.getRect(find.byKey(const Key('home_month_calendar'))),
      const Rect.fromLTWH(15, 330, 360, 391),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../goldens/goldens/home_default_390x844.png'),
    );
    debugDisableShadows = true;
  });

  testWidgets('Home loading masks only the month content', (tester) async {
    await _pumpHomeFixture(tester, MonthlySchedulesStatus.loading);

    expect(find.byKey(const Key('home_hero')), findsOneWidget);
    expect(find.byKey(const Key('today_schedule_card')), findsOneWidget);
    expect(find.byKey(const Key('home_month_loading_overlay')), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../goldens/goldens/home_loading_390x844.png'),
    );
    debugDisableShadows = true;
  });

  testWidgets('Home error keeps today visible and offers retry', (
    tester,
  ) async {
    await _pumpHomeFixture(tester, MonthlySchedulesStatus.error);

    expect(find.byKey(const Key('home_hero')), findsOneWidget);
    expect(find.byKey(const Key('today_schedule_card')), findsOneWidget);
    expect(find.byKey(const Key('home_month_error_overlay')), findsOneWidget);
    expect(find.byKey(const Key('home_month_retry')), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../goldens/goldens/home_error_390x844.png'),
    );
    debugDisableShadows = true;
  });
}

Future<void> _pumpHomeFixture(
  WidgetTester tester,
  MonthlySchedulesStatus status,
) async {
  debugDisableShadows = false;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.padding = FakeViewPadding(top: 44, bottom: 21);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => BottomNavBarScaffold(
          child: HomeScreenContent(
            state: MonthlySchedulesState(
              status: status,
              schedules: _calendarEvents(),
            ),
            userScore: 80,
            referenceDate: DateTime(2024, 12, 21),
          ),
        ),
      ),
      GoRoute(
        path: '/myPage',
        builder: (_, _) => const Scaffold(body: Text('My Page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<ScheduleBloc>.value(
      value: _VisualScheduleBloc(ScheduleState.upcoming(_todaySchedule())),
      child: MaterialApp.router(
        theme: themeData,
        locale: const Locale('ko'),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  if (status == MonthlySchedulesStatus.loading) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  } else {
    await tester.pumpAndSettle();
  }
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('home_mascot.png', package: 'assets'),
      tester.element(find.byType(HomeScreenContent)),
    );
  });
  await tester.pump();
}

class _VisualScheduleBloc extends Mock implements ScheduleBloc {
  _VisualScheduleBloc(this._state);

  final ScheduleState _state;

  @override
  ScheduleState get state => _state;

  @override
  Stream<ScheduleState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

ScheduleWithPreparationEntity _todaySchedule() => ScheduleWithPreparationEntity(
  id: 'figma-today',
  place: const PlaceEntity(id: 'place-1', placeName: '카페'),
  scheduleName: 'OO과 데이트',
  scheduleTime: DateTime(2024, 5, 12, 18),
  moveTime: const Duration(minutes: 20),
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: const Duration(minutes: 10),
  scheduleNote: '',
  preparation: const PreparationWithTimeEntity(
    preparationStepList: [
      PreparationStepWithTimeEntity(
        id: 'prep-1',
        preparationName: '준비',
        preparationTime: Duration(minutes: 10),
        nextPreparationId: null,
      ),
    ],
  ),
);

Map<DateTime, List<ScheduleEntity>> _calendarEvents() => {
  for (final count in {4: 3, 8: 2, 14: 1, 20: 3}.entries)
    DateTime(2024, 12, count.key): [
      for (var index = 0; index < count.value; index++)
        ScheduleEntity(
          id: 'calendar-${count.key}-$index',
          place: const PlaceEntity(id: 'place-2', placeName: '카페'),
          scheduleName: '일정',
          scheduleTime: DateTime(2024, 12, count.key, 12),
          moveTime: const Duration(minutes: 20),
          isChanged: false,
          isStarted: false,
          scheduleSpareTime: const Duration(minutes: 10),
          scheduleNote: '',
        ),
    ],
};
