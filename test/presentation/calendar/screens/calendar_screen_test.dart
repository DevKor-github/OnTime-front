import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_month_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_preparations_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/calendar/screens/calendar_screen.dart';
import 'package:on_time_front/presentation/shared/components/calendar/centered_calendar_header.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../helpers/visual_test_fonts.dart';

class _FakeSvgAssetBundle extends CachingAssetBundle {
  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"></svg>';

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(_svg));
    return ByteData.view(bytes.buffer);
  }
}

class _StubLoadSchedulesForMonthUseCase
    implements LoadSchedulesForMonthUseCase {
  _StubLoadSchedulesForMonthUseCase({this.failuresRemaining = 0, this.hold});

  int failuresRemaining;
  final Completer<void>? hold;
  final calls = <DateTime>[];

  @override
  Future<void> call(DateTime date) async {
    calls.add(date);
    await hold?.future;
    if (failuresRemaining-- > 0) {
      throw Exception('month unavailable');
    }
  }
}

class _StubGetSchedulesByDateUseCase implements GetSchedulesByDateUseCase {
  _StubGetSchedulesByDateUseCase(this.schedules);

  final List<ScheduleEntity> schedules;

  @override
  Stream<List<ScheduleEntity>> call(DateTime startDate, DateTime endDate) {
    return Stream.value(schedules);
  }
}

class _StubDeleteScheduleUseCase implements DeleteScheduleUseCase {
  _StubDeleteScheduleUseCase({this.error});

  final Object? error;
  final deletedSchedules = <ScheduleEntity>[];

  @override
  Future<void> call(ScheduleEntity schedule) async {
    deletedSchedules.add(schedule);
    final nextError = error;
    if (nextError != null) {
      throw nextError;
    }
  }
}

class _StubLoadPreparationByScheduleIdUseCase
    implements LoadPreparationByScheduleIdUseCase {
  @override
  Future<void> call(String scheduleId) async {}
}

class _StubGetPreparationByScheduleIdUseCase
    implements GetPreparationByScheduleIdUseCase {
  @override
  Future<PreparationEntity> call(String scheduleId) async {
    return const PreparationEntity(preparationStepList: []);
  }
}

class _StubStreamPreparationsUseCase implements StreamPreparationsUseCase {
  @override
  Stream<Map<String, PreparationEntity>> call() {
    return const Stream.empty();
  }
}

class _StubScheduleBloc extends Mock implements ScheduleBloc {
  @override
  ScheduleState get state => const ScheduleState.notExists();

  @override
  Stream<ScheduleState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualTestFonts);

  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpCalendarScreen(
    WidgetTester tester, {
    required Size size,
    required DateTime initialDate,
    DateTime? referenceDate,
    List<ScheduleEntity> schedules = const [],
    double textScale = 1.0,
    Locale locale = const Locale('en'),
    bool visual = false,
    _StubLoadSchedulesForMonthUseCase? loadSchedulesForMonthUseCase,
    _StubDeleteScheduleUseCase? deleteScheduleUseCase,
    CalendarCreateSheetBuilder? createSheetBuilder,
    bool settle = true,
  }) async {
    final loadUseCase =
        loadSchedulesForMonthUseCase ?? _StubLoadSchedulesForMonthUseCase();
    getIt.registerFactory<MonthlySchedulesBloc>(
      () => MonthlySchedulesBloc(
        loadUseCase,
        _StubGetSchedulesByDateUseCase(schedules),
        deleteScheduleUseCase ?? _StubDeleteScheduleUseCase(),
        _StubLoadPreparationByScheduleIdUseCase(),
        _StubGetPreparationByScheduleIdUseCase(),
        _StubStreamPreparationsUseCase(),
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    if (visual) {
      tester.view.padding = FakeViewPadding(top: 44, bottom: 21);
      addTearDown(tester.view.resetPadding);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = MaterialApp(
      theme: themeData,
      locale: locale,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: visual
              ? const EdgeInsets.only(top: 44, bottom: 21)
              : EdgeInsets.zero,
        ),
        child: BlocProvider<ScheduleBloc>.value(
          value: _StubScheduleBloc(),
          child: CalendarScreen(
            initialDate: initialDate,
            referenceDate: referenceDate,
            createSheetBuilder: createSheetBuilder,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      visual
          ? app
          : DefaultAssetBundle(bundle: _FakeSvgAssetBundle(), child: app),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('calendar empty shell can be compared with Figma', (
    tester,
  ) async {
    await pumpCalendarScreen(
      tester,
      size: const Size(390, 852),
      initialDate: DateTime(2024, 12, 21),
      referenceDate: DateTime(2024, 12, 1),
      schedules: _calendarMarkerSchedules(),
      locale: const Locale('ko'),
      visual: true,
    );

    expect(find.text('2024년 12월'), findsOneWidget);
    expect(find.text('약속이 없어요'), findsOneWidget);
    expect(find.text('약속 추가하기'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('calendar_card'))),
      const Rect.fromLTWH(18, 110, 354, 390),
    );
    expect(
      tester.getSize(find.widgetWithText(ElevatedButton, '약속 추가하기')).height,
      greaterThanOrEqualTo(44),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../goldens/goldens/calendar_empty_390x852.png'),
    );
  });

  for (final variant in [
    'list',
    'expanded',
    'swipe_actions',
    'expanded_actions',
    'delete_confirm',
  ]) {
    testWidgets('calendar $variant matches source card geometry and actions', (
      tester,
    ) async {
      final deletion = _StubDeleteScheduleUseCase();
      await pumpCalendarScreen(
        tester,
        size: const Size(390, 852),
        initialDate: DateTime(2024, 12, 21),
        referenceDate: DateTime(2024, 12, 1),
        schedules: [
          ..._calendarMarkerSchedules(),
          for (var index = 0; index < 2; index++)
            ScheduleEntity(
              id: 'figma-$index',
              place: const PlaceEntity(id: 'place', placeName: '약속 장소'),
              scheduleName: '약속 이름',
              scheduleTime: DateTime(2024, 12, 21, 18 + index),
              moveTime: const Duration(minutes: 80),
              isChanged: false,
              isStarted: false,
              scheduleSpareTime: const Duration(minutes: 10),
              scheduleNote: '',
            ),
        ],
        deleteScheduleUseCase: deletion,
        locale: const Locale('ko'),
        visual: true,
      );
      final expanded =
          variant == 'expanded' ||
          variant == 'expanded_actions' ||
          variant == 'delete_confirm';
      if (expanded) {
        await tester.tap(find.text('약속 이름').first);
        await tester.pumpAndSettle();
      }
      expect(
        tester.getSize(find.byKey(const ValueKey('schedule_card_figma-0'))),
        Size(354, expanded ? 192 : 82),
      );
      if (variant.contains('actions') || variant == 'delete_confirm') {
        await tester.drag(
          find.byType(SwipeActionCell).first,
          const Offset(-210, 0),
        );
        await tester.pumpAndSettle();
      }
      if (variant == 'delete_confirm') {
        final deleteAction = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  const Color(0xffbf2e22),
        );
        await tester.tap(deleteAction.first);
        await tester.pumpAndSettle();
        expect(deletion.deletedSchedules, isEmpty);
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../../goldens/goldens/calendar_${variant}_390x852.png',
        ),
      );
      if (variant == 'delete_confirm') {
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(deletion.deletedSchedules, isEmpty);
        expect(find.text('약속 이름'), findsNWidgets(2));
      }
    });
  }

  testWidgets('compact future empty state fits with add button', (
    tester,
  ) async {
    final futureDate = DateTime.now().add(const Duration(days: 7));

    await pumpCalendarScreen(
      tester,
      size: const Size(360, 640),
      textScale: 1.3,
      initialDate: futureDate,
    );

    expect(find.text('No schedules'), findsOneWidget);
    expect(find.text('Add appointment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short past empty state fits without add button', (tester) async {
    final pastDate = DateTime.now().subtract(const Duration(days: 7));

    await pumpCalendarScreen(
      tester,
      size: const Size(360, 560),
      textScale: 1.3,
      initialDate: pastDate,
    );

    expect(find.text('No schedules'), findsOneWidget);
    expect(find.text('Add appointment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact selected day with schedules scrolls without overflow', (
    tester,
  ) async {
    final selectedDate = DateTime.now().add(const Duration(days: 7));
    final schedule = ScheduleEntity(
      id: 'schedule-1',
      place: PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: 'Design Review',
      scheduleTime: DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        9,
      ),
      moveTime: const Duration(minutes: 30),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
    );

    await pumpCalendarScreen(
      tester,
      size: const Size(360, 640),
      textScale: 1.3,
      initialDate: selectedDate,
      schedules: [schedule],
    );

    expect(find.text('Design Review'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial date before supported range is clamped to first month', (
    tester,
  ) async {
    final loadUseCase = _StubLoadSchedulesForMonthUseCase();

    await pumpCalendarScreen(
      tester,
      size: const Size(390, 844),
      initialDate: DateTime(2024, 1, 15),
      loadSchedulesForMonthUseCase: loadUseCase,
    );

    expect(find.text('December 2024'), findsOneWidget);
    expect(loadUseCase.calls.single, DateTime(2024, 12, 1));
  });

  testWidgets('calendar header arrows move the visible month', (tester) async {
    await pumpCalendarScreen(
      tester,
      size: const Size(390, 844),
      initialDate: DateTime(2026, 1, 15),
    );

    expect(find.text('January 2026'), findsOneWidget);

    final headerButtons = find.descendant(
      of: find.byType(CenteredCalendarHeader),
      matching: find.byType(IconButton),
    );

    await tester.tap(headerButtons.at(1));
    await tester.pumpAndSettle();

    expect(find.text('February 2026'), findsOneWidget);
    expect(find.text('February 1'), findsOneWidget);

    await tester.tap(headerButtons.at(0));
    await tester.pumpAndSettle();

    expect(find.text('January 2026'), findsOneWidget);
    expect(find.text('January 1'), findsOneWidget);
  });

  testWidgets('selecting another day updates the detail list for that day', (
    tester,
  ) async {
    final firstDay = DateTime(2026, 1, 15);
    final secondDay = DateTime(2026, 1, 20);
    final schedules = [
      _schedule(id: 'first', name: 'Initial day appointment', date: firstDay),
      _schedule(
        id: 'second',
        name: 'Selected day appointment',
        date: secondDay,
      ),
    ];

    await pumpCalendarScreen(
      tester,
      size: const Size(390, 844),
      initialDate: firstDay,
      schedules: schedules,
    );

    expect(find.text('Initial day appointment'), findsOneWidget);
    expect(find.text('Selected day appointment'), findsNothing);

    await tester.tap(find.text('20').first);
    await tester.pumpAndSettle();

    expect(find.text('January 20'), findsOneWidget);
    expect(find.text('Initial day appointment'), findsNothing);
    expect(find.text('Selected day appointment'), findsOneWidget);
  });

  testWidgets('saved create sheet refreshes the selected calendar date', (
    tester,
  ) async {
    final selectedDate = DateTime.now().add(const Duration(days: 7));
    final loadUseCase = _StubLoadSchedulesForMonthUseCase();
    DateTime? sheetInitialDate;

    await pumpCalendarScreen(
      tester,
      size: const Size(390, 844),
      initialDate: selectedDate,
      loadSchedulesForMonthUseCase: loadUseCase,
      createSheetBuilder: (context, initialDate) {
        sheetInitialDate = initialDate;
        return Material(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save new appointment'),
          ),
        );
      },
    );

    await tester.tap(find.text('Add appointment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new appointment'));
    await tester.pumpAndSettle();

    expect(
      sheetInitialDate,
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
    );
    expect(
      loadUseCase.calls.last,
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
    );
  });

  testWidgets('month load failures show calendar error state', (tester) async {
    final load = _StubLoadSchedulesForMonthUseCase(failuresRemaining: 1);
    await pumpCalendarScreen(
      tester,
      size: const Size(390, 852),
      initialDate: DateTime(2024, 12, 21),
      referenceDate: DateTime(2024, 12, 1),
      locale: const Locale('ko'),
      visual: true,
      loadSchedulesForMonthUseCase: load,
    );

    expect(find.text('오류'), findsOneWidget);
    expect(find.byType(TableCalendar), findsNothing);
    expect(find.byKey(const Key('calendar_month_retry')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('calendar_card'))),
      const Rect.fromLTWH(18, 110, 354, 390),
    );
    expect(tester.getTopLeft(find.text('오류')).dy, inInclusiveRange(250, 265));
    expect(
      tester.getTopLeft(find.byKey(const Key('calendar_month_retry'))).dy,
      inInclusiveRange(290, 305),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../goldens/goldens/calendar_error_390x852.png'),
    );

    await tester.tap(find.byKey(const Key('calendar_month_retry')));
    await tester.pumpAndSettle();
    expect(load.calls, hasLength(2));
    expect(find.byType(TableCalendar), findsOneWidget);
    expect(find.byKey(const Key('calendar_month_retry')), findsNothing);
  });

  testWidgets('month loading keeps its fixed surface and blocks date actions', (
    tester,
  ) async {
    final pending = Completer<void>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete();
    });
    await pumpCalendarScreen(
      tester,
      size: const Size(390, 852),
      initialDate: DateTime(2024, 12, 21),
      referenceDate: DateTime(2024, 12, 1),
      locale: const Locale('ko'),
      visual: true,
      loadSchedulesForMonthUseCase: _StubLoadSchedulesForMonthUseCase(
        hold: pending,
      ),
      settle: false,
    );
    expect(find.byType(TableCalendar), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('약속 추가하기'), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('calendar_card'))),
      const Rect.fromLTWH(18, 110, 354, 390),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../../goldens/goldens/calendar_loading_390x852.png',
      ),
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TableCalendar), findsOneWidget);
  });

  testWidgets('delete failure keeps calendar visible and shows error dialog', (
    tester,
  ) async {
    final selectedDate = DateTime.now().add(const Duration(days: 7));
    final schedule = ScheduleEntity(
      id: 'schedule-1',
      place: PlaceEntity(id: 'place-1', placeName: 'Office'),
      scheduleName: 'Design Review',
      scheduleTime: DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        9,
      ),
      moveTime: const Duration(minutes: 30),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '',
    );
    final deleteUseCase = _StubDeleteScheduleUseCase(
      error: Exception('cannot delete'),
    );

    await pumpCalendarScreen(
      tester,
      size: const Size(390, 844),
      initialDate: selectedDate,
      schedules: [schedule],
      deleteScheduleUseCase: deleteUseCase,
    );

    await tester.drag(find.byType(SwipeActionCell), const Offset(-180, 0));
    await tester.pumpAndSettle();

    final deleteAction = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == const Color(0xffbf2e22);
    });
    expect(deleteAction, findsOneWidget);

    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete appointment'));
    await tester.pumpAndSettle();

    expect(deleteUseCase.deletedSchedules, [schedule]);
    expect(find.text('Appointment cannot be deleted'), findsOneWidget);
    expect(
      find.textContaining('This appointment can no longer be deleted'),
      findsOneWidget,
    );
    expect(find.text('Design Review'), findsOneWidget);
    expect(find.byType(TableCalendar), findsOneWidget);
  });

  testWidgets('android system back from calendar returns to home', (
    tester,
  ) async {
    getIt.registerFactory<MonthlySchedulesBloc>(
      () => MonthlySchedulesBloc(
        _StubLoadSchedulesForMonthUseCase(),
        _StubGetSchedulesByDateUseCase(const []),
        _StubDeleteScheduleUseCase(),
        _StubLoadPreparationByScheduleIdUseCase(),
        _StubGetPreparationByScheduleIdUseCase(),
        _StubStreamPreparationsUseCase(),
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('Home Screen')),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text('Home Screen'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsNothing);
    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets('app bar back button returns to home', (tester) async {
    getIt.registerFactory<MonthlySchedulesBloc>(
      () => MonthlySchedulesBloc(
        _StubLoadSchedulesForMonthUseCase(),
        _StubGetSchedulesByDateUseCase(const []),
        _StubDeleteScheduleUseCase(),
        _StubLoadPreparationByScheduleIdUseCase(),
        _StubGetPreparationByScheduleIdUseCase(),
        _StubStreamPreparationsUseCase(),
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('Home Screen')),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarScreen), findsNothing);
    expect(find.text('Home Screen'), findsOneWidget);
  });
}

ScheduleEntity _schedule({
  required String id,
  required String name,
  required DateTime date,
}) {
  return ScheduleEntity(
    id: id,
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: name,
    scheduleTime: DateTime(date.year, date.month, date.day, 9),
    moveTime: const Duration(minutes: 30),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 10),
    scheduleNote: '',
  );
}

List<ScheduleEntity> _calendarMarkerSchedules() => [
  for (final entry in {4: 3, 8: 2, 14: 1, 20: 3}.entries)
    for (var index = 0; index < entry.value; index++)
      _schedule(
        id: 'marker-${entry.key}-$index',
        name: '달력 일정',
        date: DateTime(2024, 12, entry.key),
      ),
];
