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

  for (final phase in ['date', 'zone-list', 'zone-apply']) {
    testWidgets(
      'old $phase modal cannot apply or validate a replacement form',
      (tester) async {
        final form = _FakeScheduleFormBloc(
          ScheduleFormState(
            id: 'original',
            scheduleTime: DateTime.utc(2030, 1, 2, 10),
            timeZoneId: 'UTC',
            occurrenceOffsetSeconds: 0,
          ),
        );
        final adjacent = _FakeGetAdjacentSchedulesWithPreparationUseCase();
        final cubit = ScheduleDateTimeCubit(
          form,
          _FakeLoadAdjacentSchedulesWithPreparationUseCase(),
          adjacent,
        )..initialize();
        addTearDown(cubit.close);
        await _pumpForm(tester, cubit: cubit);
        if (phase == 'date') {
          await tester.tap(find.byType(TextField).first);
        } else {
          await tester.tap(find.text('UTC'));
        }
        await tester.pumpAndSettle();
        if (phase != 'date') {
          await tester.enterText(find.byType(TextField).last, 'Asia/Seoul');
          await tester.pumpAndSettle();
          if (phase == 'zone-apply') {
            await tester.tap(
              find.widgetWithText(ListTile, 'Seoul · Asia/Seoul'),
            );
            await tester.pumpAndSettle();
            expect(find.text('Selection preview'), findsOneWidget);
          }
        }
        form.replaceOwner();
        final before = cubit.state;
        final validations = form.addedEvents.length;
        final requests = adjacent.calls.length;
        if (phase == 'date') {
          await tester.tap(find.byKey(const ValueKey('civil-picker-confirm')));
        } else if (phase == 'zone-list') {
          await tester.tap(find.widgetWithText(ListTile, 'Seoul · Asia/Seoul'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('time-zone-apply')));
        } else {
          await tester.tap(find.byKey(const ValueKey('time-zone-apply')));
        }
        await tester.pumpAndSettle();
        expect(cubit.state, before);
        expect(form.addedEvents.length, validations);
        expect(adjacent.calls.length, requests);
        expect(find.text('Confirm time zone'), findsNothing);
      },
    );
  }

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

  testWidgets('shows explicit choices for a repeated DST time', (tester) async {
    final formBloc = _FakeScheduleFormBloc(
      ScheduleFormState(id: 'schedule-1', timeZoneId: 'America/New_York'),
    );
    final cubit = ScheduleDateTimeCubit(
      formBloc,
      _FakeLoadAdjacentSchedulesWithPreparationUseCase(),
      _FakeGetAdjacentSchedulesWithPreparationUseCase(),
    );
    addTearDown(cubit.close);
    cubit.initialize();

    await cubit.scheduleDateChanged(DateTime(2027, 11, 7));
    await cubit.scheduleTimeChanged(DateTime(2027, 11, 7, 1, 30));
    await _pumpForm(tester, cubit: cubit);

    expect(find.textContaining('occurs twice'), findsOneWidget);
    expect(find.text('First occurrence (UTC-04:00)'), findsOneWidget);
    expect(find.text('Second occurrence (UTC-05:00)'), findsOneWidget);

    final second = find.text('Second occurrence (UTC-05:00)');
    await tester.scrollUntilVisible(
      second,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(second), alignment: .5);
    await tester.pumpAndSettle();
    expect(second.hitTestable(), findsOneWidget);
    await tester.tap(second);
    await tester.pump();

    expect(cubit.state.selectedOccurrenceOffsetSeconds, -5 * 60 * 60);
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

  ScheduleFormState _state;
  Object _owner = Object();
  @override
  Object get formOwner => _owner;
  @override
  bool ownsForm(Object owner) => identical(owner, _owner);
  void replaceOwner() {
    _owner = Object();
    _state = ScheduleFormState(id: 'replacement');
  }

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
