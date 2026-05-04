import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/screens/home_screen_tmp.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class StubAuthBloc extends Mock implements AuthBloc {
  StubAuthBloc(this._state);

  final AuthState _state;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

class StubScheduleBloc extends Mock implements ScheduleBloc {
  StubScheduleBloc(this._state);

  final ScheduleState _state;

  @override
  ScheduleState get state => _state;

  @override
  Stream<ScheduleState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({
    required Size size,
    required ScheduleState scheduleState,
    double textScale = 1.0,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final authBloc = StubAuthBloc(
      AuthState(
        user: UserEntity(
          id: 'user-1',
          name: 'Test User',
          email: 'test@example.com',
          spareTime: Duration.zero,
          note: '',
          score: 80,
          isOnboardingCompleted: true,
        ),
      ),
    );
    final scheduleBloc = StubScheduleBloc(scheduleState);

    return MaterialApp(
      theme: themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: padding,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<ScheduleBloc>.value(value: scheduleBloc),
          ],
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: HomeScreenContent(
              state: const MonthlySchedulesState(
                status: MonthlySchedulesStatus.success,
              ),
              userScore: 80,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('compact portrait home fits without scroll at 1.3 text scale',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildSubject(
        size: const Size(360, 640),
        textScale: 1.3,
        scheduleState: const ScheduleState.notExists(),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.getSize(find.byKey(const Key('home_banner'))).width, 360);
    expect(tester.getSize(find.byKey(const Key('today_schedule_card'))).width,
        328);
    expect(
      tester.getSize(find.byKey(const Key('home_banner'))).height,
      closeTo(116, 1),
    );
    expect(_verticalGap(tester, 'home_banner', 'today_schedule_card'), 0);
    expect(
        _bottomGap(tester, 'home_month_calendar', 640), lessThanOrEqualTo(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact portrait home fits when today schedule exists',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildSubject(
        size: const Size(360, 640),
        textScale: 1.3,
        scheduleState: ScheduleState.upcoming(_scheduleWithLongName()),
      ),
    );
    await tester.pump();

    expect(_verticalGap(tester, 'home_banner', 'today_schedule_card'), 0);
    expect(
        _bottomGap(tester, 'home_month_calendar', 640), lessThanOrEqualTo(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('regular portrait home matches Figma hero and card geometry',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildSubject(
        size: const Size(390, 844),
        scheduleState: const ScheduleState.notExists(),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byKey(const Key('home_banner'))).width, 390);
    expect(tester.getSize(find.byKey(const Key('today_schedule_card'))).width,
        358);
    expect(tester.getSize(find.byKey(const Key('today_schedule_card'))).height,
        137);
    expect(_top(tester, 'home_banner'), closeTo(51, 1));
    expect(_top(tester, 'today_schedule_card'), closeTo(177, 1));
    expect(_top(tester, 'today_background_surface'), closeTo(230, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner clears the device safe area before rendering',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildSubject(
        size: const Size(390, 844),
        padding: const EdgeInsets.only(top: 59),
        scheduleState: const ScheduleState.notExists(),
      ),
    );
    await tester.pump();

    expect(_top(tester, 'home_banner'), greaterThanOrEqualTo(71));
    expect(
        _bottomGap(tester, 'home_month_calendar', 844), lessThanOrEqualTo(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('today schedule tile truncates long schedule names',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: TodaysScheduleTile(
              schedule: _scheduleWithLongName(),
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final titleText = tester.widget<Text>(
      find.text(_scheduleWithLongName().scheduleName),
    );

    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}

double _verticalGap(
  WidgetTester tester,
  String upperKey,
  String lowerKey,
) {
  final upperBox = tester.renderObject<RenderBox>(find.byKey(Key(upperKey)));
  final lowerBox = tester.renderObject<RenderBox>(find.byKey(Key(lowerKey)));
  final upperBottom =
      upperBox.localToGlobal(Offset.zero).dy + upperBox.size.height;
  final lowerTop = lowerBox.localToGlobal(Offset.zero).dy;

  return lowerTop - upperBottom;
}

double _bottomGap(
  WidgetTester tester,
  String key,
  double screenHeight,
) {
  final box = tester.renderObject<RenderBox>(find.byKey(Key(key)));
  return screenHeight - (box.localToGlobal(Offset.zero).dy + box.size.height);
}

double _top(WidgetTester tester, String key) {
  final box = tester.renderObject<RenderBox>(find.byKey(Key(key)));
  return box.localToGlobal(Offset.zero).dy;
}

ScheduleWithPreparationEntity _scheduleWithLongName() {
  return ScheduleWithPreparationEntity(
    id: 'schedule-1',
    place: PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName:
        'Very long appointment name that should never force the home screen to scroll',
    scheduleTime: DateTime.now().add(const Duration(hours: 3)),
    moveTime: const Duration(minutes: 20),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 10),
    scheduleNote: '',
    preparation: const PreparationWithTimeEntity(
      preparationStepList: [
        PreparationStepWithTimeEntity(
          id: 'prep-1',
          preparationName: 'Get ready',
          preparationTime: Duration(minutes: 15),
          nextPreparationId: null,
        ),
      ],
    ),
  );
}
