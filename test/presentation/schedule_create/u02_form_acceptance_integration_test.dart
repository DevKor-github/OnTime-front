import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_date_time_form.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import '../../helpers/u02_save_fixture.dart';

// The adjacent-query boundary is controlled and counted; draft ownership,
// selection, submission, writer, and persisted edit load are production code.
class _LoadAdjacent extends Fake
    implements LoadAdjacentScheduleWithPreparationUseCase {
  @override
  Future<void> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {}
}

class _Adjacent extends Fake
    implements GetAdjacentSchedulesWithPreparationUseCase {
  final calls = <DateTime>[];
  @override
  Future<AdjacentSchedulesWithPreparationEntity> call({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    calls.add(selectedDateTime);
    return const AdjacentSchedulesWithPreparationEntity();
  }
}

Future<void> _mount(
  WidgetTester tester,
  U02SaveFixture f,
  ScheduleDateTimeCubit cubit,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: BlocProvider.value(
          value: f.bloc,
          child: BlocProvider.value(
            value: cubit,
            child: const ScheduleDateTimeForm(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: scrollable ?? find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _pickZone(
  WidgetTester tester,
  String current,
  String next,
  String city,
) async {
  final zoneTile = find.widgetWithText(ListTile, current);
  await _reveal(tester, zoneTile);
  await tester.tap(zoneTile);
  await tester.pumpAndSettle();
  final scrollable = find
      .descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      )
      .first;
  final search = find.byKey(const ValueKey('time-zone-search'));
  await _reveal(tester, search, scrollable: scrollable);
  await tester.enterText(search, next);
  await tester.pumpAndSettle();
  final candidate = find.widgetWithText(ListTile, '$city · $next');
  await _reveal(tester, candidate, scrollable: scrollable);
  await tester.tap(candidate);
  await tester.pumpAndSettle();
  final apply = find.byKey(const ValueKey('time-zone-apply'));
  expect(apply.hitTestable(), findsOneWidget);
  await tester.tap(apply);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'U02-08 actual gap proposal cancel and apply revalidate before any SQLite write',
    (tester) async {
      final f = U02SaveFixture();
      await tester.runAsync(f.open);
      await tester.runAsync(() => f.draft(-18000));
      addTearDown(f.close);
      final gap = DateTime.utc(2027, 3, 14, 2, 30);
      await tester.runAsync(
        () => f.send(
          ScheduleFormScheduleDateTimeChanged(
            scheduleDate: gap,
            scheduleTime: gap,
            timeZoneId: 'America/New_York',
            occurrenceOffsetSeconds: -18000,
          ),
          (s) => s.scheduleTime == gap,
        ),
      );
      final adjacent = _Adjacent();
      final cubit = ScheduleDateTimeCubit(f.bloc, _LoadAdjacent(), adjacent)
        ..initialize();
      addTearDown(cubit.close);
      await _mount(tester, f, cubit);
      final beforeRevision = await tester.runAsync(f.revision);
      expect(cubit.state.isNonexistentCivilTime, isTrue);
      expect(cubit.scheduleDateTimeSubmitted(), isFalse);
      final proposal = find.widgetWithText(
        TextButton,
        'Review next valid time',
      );
      await _reveal(tester, proposal);
      await tester.tap(proposal);
      await tester.pumpAndSettle();
      expect(find.textContaining('2027-03-14T07:00:00.000Z'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(cubit.state.selectedScheduleDateTime, gap);
      expect(cubit.scheduleDateTimeSubmitted(), isFalse);
      final queriesBeforeApply = adjacent.calls.length;
      await tester.tap(proposal);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(
        cubit.state.selectedScheduleDateTime,
        DateTime.utc(2027, 3, 14, 3),
      );
      expect(cubit.state.selectedOccurrenceOffsetSeconds, -14400);
      expect(cubit.state.isNonexistentCivilTime, isFalse);
      expect(adjacent.calls.length, greaterThan(queriesBeforeApply));
      expect(adjacent.calls.last, DateTime.utc(2027, 3, 14, 7));
      expect(cubit.state.isValid, isTrue);
      expect(cubit.scheduleDateTimeSubmitted(), isTrue);
      await tester.pump();
      expect(f.bloc.state.scheduleTime, DateTime.utc(2027, 3, 14, 3));
      expect(
        await tester.runAsync(() => f.db.select(f.db.schedules).get()),
        isEmpty,
      );
      expect(await tester.runAsync(f.revision), beforeRevision);
      expect(f.effects.calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'U02-10 selected fold is invalidated by actual zone picker round trip',
    (tester) async {
      final f = U02SaveFixture();
      await tester.runAsync(f.open);
      await tester.runAsync(() => f.draft(-18000));
      addTearDown(f.close);
      final cubit = ScheduleDateTimeCubit(f.bloc, _LoadAdjacent(), _Adjacent())
        ..initialize();
      addTearDown(cubit.close);
      await _mount(tester, f, cubit);
      final civil = cubit.state.selectedScheduleDateTime;
      expect(cubit.state.selectedOccurrenceOffsetSeconds, -18000);
      await _pickZone(tester, 'America/New_York', 'Asia/Seoul', 'Seoul');
      expect(cubit.state.selectedScheduleDateTime, civil);
      expect(cubit.state.selectedOccurrenceOffsetSeconds, 32400);
      await _pickZone(tester, 'Asia/Seoul', 'America/New_York', 'New York');
      expect(cubit.state.selectedScheduleDateTime, civil);
      expect(cubit.state.requiresOccurrenceChoice, isTrue);
      expect(cubit.state.selectedOccurrenceOffsetSeconds, isNull);
      expect(cubit.scheduleDateTimeSubmitted(), isFalse);
      await tester.pump();
      expect(f.bloc.state.isValid, isFalse);
      final first = find.text('First occurrence (UTC-04:00)');
      await _reveal(tester, first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(cubit.state.selectedOccurrenceOffsetSeconds, -14400);
      expect(cubit.scheduleDateTimeSubmitted(), isTrue);
      await tester.pump();
      expect(f.bloc.state.occurrenceOffsetSeconds, -14400);
      await tester.runAsync(
        () => f.send(
          const ScheduleFormCreated(),
          (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
        ),
      );
      expect(f.bloc.state.timeReview!.proposed.occurrenceOffsetSeconds, -14400);
      expect(
        f.bloc.state.timeReview!.resolution.instantUtc,
        DateTime.utc(2026, 11, 1, 5, 30, 1, 123, 456),
      );
      expect(
        await tester.runAsync(() => f.db.select(f.db.schedules).get()),
        isEmpty,
      );
      expect(f.effects.calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'U02-18 persisted alias survives actual edit picker search and cancel unchanged',
    (tester) async {
      final f = U02SaveFixture();
      await tester.runAsync(f.open);
      await tester.runAsync(() => f.draft(-18000));
      addTearDown(f.close);
      expect(TimeZoneRules.contains('US/Eastern'), isTrue);
      final civil = f.bloc.state.scheduleTime!;
      await tester.runAsync(
        () => f.send(
          ScheduleFormScheduleDateTimeChanged(
            scheduleDate: civil,
            scheduleTime: civil,
            timeZoneId: 'US/Eastern',
            occurrenceOffsetSeconds: -18000,
            timeZoneExplicitlySelected: true,
          ),
          (s) => s.timeZoneId == 'US/Eastern',
        ),
      );
      await tester.runAsync(
        () => f.send(
          const ScheduleFormCreated(),
          (s) => s.submissionStatus == ScheduleFormSubmissionStatus.timeReview,
        ),
      );
      await tester.runAsync(
        () => f.send(
          ScheduleFormTimeReviewConfirmed(f.bloc.state.timeReview!),
          (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
        ),
      );
      final id = f.bloc.state.id;
      await tester.runAsync(
        () => f.send(
          ScheduleFormEditRequested(scheduleId: id),
          (s) =>
              s.status == ScheduleFormStatus.success &&
              s.originalSchedule != null,
        ),
      );
      final beforeRows = await tester.runAsync(
        () => f.db.select(f.db.schedules).get(),
      );
      final revision = await tester.runAsync(f.revision);
      final effects = f.effects.calls;
      final cubit = ScheduleDateTimeCubit(f.bloc, _LoadAdjacent(), _Adjacent())
        ..initialize();
      addTearDown(cubit.close);
      await _mount(tester, f, cubit);
      final zoneTile = find.widgetWithText(ListTile, 'US/Eastern');
      await _reveal(tester, zoneTile);
      await tester.tap(zoneTile);
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      final search = find.byKey(const ValueKey('time-zone-search'));
      await _reveal(tester, search, scrollable: scrollable);
      await tester.enterText(search, 'America/New_York');
      await tester.pumpAndSettle();
      final candidate = find.widgetWithText(
        ListTile,
        'New York · America/New_York',
      );
      await _reveal(tester, candidate, scrollable: scrollable);
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(cubit.state.timeZoneId, 'US/Eastern');
      expect(cubit.state.selectedScheduleDateTime, civil);
      expect(cubit.state.selectedOccurrenceOffsetSeconds, -18000);
      expect(f.bloc.state.timeZoneId, 'US/Eastern');
      expect(
        await tester.runAsync(() => f.db.select(f.db.schedules).get()),
        beforeRows,
      );
      expect(await tester.runAsync(f.revision), revision);
      expect(f.effects.calls, effects);
      final reread = await tester.runAsync(() => f.aggregate.readForEdit(id));
      expect(reread!.schedule.timeZoneId, 'US/Eastern');
      expect(reread.schedule.scheduleTime, civil);
      expect(reread.schedule.occurrenceOffsetSeconds, -18000);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
