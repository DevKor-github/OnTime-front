import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/calendar/screens/calendar_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class _StubMonthlySchedulesBloc extends Mock implements MonthlySchedulesBloc {
  @override
  MonthlySchedulesState get state => const MonthlySchedulesState(
        status: MonthlySchedulesStatus.success,
      );

  @override
  Stream<MonthlySchedulesState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(MonthlySchedulesEvent event) {}

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await GetIt.instance.reset();
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('android system back from calendar returns to home',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    getIt.registerFactory<MonthlySchedulesBloc>(
      _StubMonthlySchedulesBloc.new,
    );

    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: Text('Home Screen'),
          ),
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
}
