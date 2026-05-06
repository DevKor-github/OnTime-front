import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:on_time_front/presentation/shared/theme/theme.dart';

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
  @override
  Future<void> call(DateTime date) async {}
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
  @override
  Future<void> call(ScheduleEntity schedule) async {}
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
    List<ScheduleEntity> schedules = const [],
    double textScale = 1.0,
  }) async {
    getIt.registerFactory<MonthlySchedulesBloc>(
      () => MonthlySchedulesBloc(
        _StubLoadSchedulesForMonthUseCase(),
        _StubGetSchedulesByDateUseCase(schedules),
        _StubDeleteScheduleUseCase(),
        _StubLoadPreparationByScheduleIdUseCase(),
        _StubGetPreparationByScheduleIdUseCase(),
        _StubStreamPreparationsUseCase(),
      ),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _FakeSvgAssetBundle(),
        child: MaterialApp(
          theme: themeData,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: BlocProvider<ScheduleBloc>.value(
              value: _StubScheduleBloc(),
              child: CalendarScreen(initialDate: initialDate),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact future empty state fits with add button',
      (tester) async {
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

  testWidgets('compact selected day with schedules scrolls without overflow',
      (tester) async {
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
}
