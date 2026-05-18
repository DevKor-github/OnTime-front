import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_date_time_form.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('saves date and time picker selections through the cubit', (
    tester,
  ) async {
    final scheduledAt = DateTime.now().add(const Duration(days: 2));
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(id: 'schedule-1', scheduleTime: scheduledAt),
    );
    final loader = _FakeLoadAdjacentSchedulesWithPreparationUseCase();
    final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
    final cubit = ScheduleDateTimeCubit(formBloc, loader, adjacent)
      ..initialize();
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(loader.calls, isNotEmpty);
    expect(adjacent.calls, isNotEmpty);
    expect(formBloc.addedEvents.whereType<ScheduleFormValidated>(), isNotEmpty);
  });

  testWidgets('formats selected date with Korean locale', (tester) async {
    final scheduledAt = DateTime(2026, 5, 15, 9, 30);
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(id: 'schedule-1', scheduleTime: scheduledAt),
    );
    final cubit = ScheduleDateTimeCubit(
      formBloc,
      _FakeLoadAdjacentSchedulesWithPreparationUseCase(),
      _FakeGetAdjacentSchedulesWithPreparationUseCase(),
    )..initialize();
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit, locale: const Locale('ko'));

    expect(find.text('2026년 05월 15일'), findsWidgets);
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required ScheduleDateTimeCubit cubit,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<ScheduleDateTimeCubit>.value(
          value: cubit,
          child: const ScheduleDateTimeForm(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeScheduleFormBloc implements ScheduleFormBloc {
  _FakeScheduleFormBloc(this._state);

  final ScheduleFormState _state;
  final addedEvents = <ScheduleFormEvent>[];

  @override
  ScheduleFormState get state => _state;

  @override
  Stream<ScheduleFormState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;

  @override
  void add(ScheduleFormEvent event) {
    addedEvents.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLoadAdjacentSchedulesWithPreparationUseCase
    implements LoadAdjacentScheduleWithPreparationUseCase {
  final calls = <(DateTime, DateTime)>[];

  @override
  Future<void> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    calls.add((startDate, endDate));
  }
}

class _FakeAdjacentCall {
  const _FakeAdjacentCall(this.selectedDateTime);

  final DateTime selectedDateTime;
}

class _FakeGetAdjacentSchedulesWithPreparationUseCase
    implements GetAdjacentSchedulesWithPreparationUseCase {
  final calls = <_FakeAdjacentCall>[];

  @override
  Future<AdjacentSchedulesWithPreparationEntity> call({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    calls.add(_FakeAdjacentCall(selectedDateTime));
    return const AdjacentSchedulesWithPreparationEntity();
  }
}
