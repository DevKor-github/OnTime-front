import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time/cubit/schedule_place_moving_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_place_moving_time/screens/schedule_place_moving_time_form.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('edits place name and saves travel time picker selection', (
    tester,
  ) async {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        placeName: 'Office',
        moveTime: const Duration(minutes: 20),
        scheduleTime: DateTime(2026, 5, 15, 9),
        maxAvailableTime: const Duration(minutes: 45),
      ),
    );
    final cubit = SchedulePlaceMovingTimeCubit(scheduleFormBloc: formBloc)
      ..initialize();
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit);

    await tester.enterText(find.byType(TextFormField), 'Client site');
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(cubit.state.placeName.value, 'Client site');
    expect(formBloc.addedEvents.whereType<ScheduleFormValidated>(), isNotEmpty);
  });

  testWidgets('shows overlap warning from available travel window', (
    tester,
  ) async {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(
        placeName: 'Office',
        moveTime: const Duration(minutes: 20),
        scheduleTime: DateTime(2026, 5, 15, 9),
        maxAvailableTime: const Duration(minutes: 25),
        previousScheduleName: 'Previous meeting',
      ),
    );
    final cubit = SchedulePlaceMovingTimeCubit(scheduleFormBloc: formBloc)
      ..initialize();
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit);

    expect(find.textContaining('Previous meeting'), findsOneWidget);
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required SchedulePlaceMovingTimeCubit cubit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<ScheduleFormBloc>.value(
          value: cubit.scheduleFormBloc,
          child: BlocProvider<SchedulePlaceMovingTimeCubit>.value(
            value: cubit,
            child: const SchedulePlaceMovingTimeForm(),
          ),
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
