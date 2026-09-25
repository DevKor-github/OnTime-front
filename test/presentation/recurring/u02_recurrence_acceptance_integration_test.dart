import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/adjacent_schedules_with_preparation_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/get_adjacent_schedules_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurrence_review_sheet.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/components/schedule_multi_page_form.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/cubit/schedule_date_time_cubit.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';
import '../../helpers/u02_save_fixture.dart';

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
  @override
  Future<AdjacentSchedulesWithPreparationEntity> call({
    required DateTime selectedDateTime,
    String? currentScheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async => const AdjacentSchedulesWithPreparationEntity();
}

Future<void> _mount(
  WidgetTester tester,
  U02SaveFixture f, {
  required bool editing,
}) async {
  getIt.registerFactoryParam<ScheduleDateTimeCubit, ScheduleFormBloc, void>(
    (form, _) => ScheduleDateTimeCubit(form, _LoadAdjacent(), _Adjacent()),
  );
  addTearDown(getIt.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: BlocProvider.value(
                    value: f.bloc,
                    child: ScheduleMultiPageForm(
                      onSaved: () => f.bloc.add(
                        editing
                            ? const ScheduleFormUpdated()
                            : const ScheduleFormCreated(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Open actual form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open actual form'));
  await tester.pumpAndSettle();
}

Future<void> _review(
  WidgetTester tester,
  U02SaveFixture f, {
  required bool editing,
}) async {
  await tester.runAsync(
    () => f.send(
      editing ? const ScheduleFormUpdated() : const ScheduleFormCreated(),
      (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(RecurrenceReviewSheet), findsOneWidget);
}

Finder _action(String text) => find.descendant(
  of: find.byType(RecurrenceReviewSheet),
  matching: find.text(text),
);
Future<void> _confirm(WidgetTester tester, U02SaveFixture f) async {
  final saved = f.bloc.stream.firstWhere(
    (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
  );
  expect(_action('Save').hitTestable(), findsOneWidget);
  await tester.tap(_action('Save'));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.runAsync(() => saved.timeout(const Duration(seconds: 5)));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'U02-17 actual finite-rule validation rejection requires a new review before retry',
    () async {
      final f = U02SaveFixture();
      await f.open();
      addTearDown(f.close);
      await f.draft(-14400);
      await f.send(
        ScheduleFormRecurringChanged(
          RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            start: f.bloc.state.scheduleTime!,
            timeZoneId: 'America/New_York',
            until: DateTime.utc(2026, 11, 2),
            repeatedTime: RepeatedCivilTime.first,
          ),
        ),
        (s) => s.recurrenceRule != null,
      );
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
      );
      final stale = f.bloc.state.recurrenceReview!;
      final before = await f.revision();
      f.now = DateTime.utc(2026, 12, 1);
      await f.send(
        ScheduleFormRecurrenceReviewConfirmed(stale),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.failure,
      );
      expect(f.bloc.state.submissionError, '이 조건으로 만들 수 있는 일정이 없어요.');
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      expect(await f.revision(), before);
      expect(f.effects.calls, 0);
      f.now = DateTime.utc(2026, 10, 1);
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
      );
      final fresh = f.bloc.state.recurrenceReview!;
      expect(identical(fresh, stale), isFalse);
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      await f.send(
        ScheduleFormRecurrenceReviewConfirmed(fresh),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      expect(await f.db.select(f.db.schedules).get(), hasLength(2));
      expect(await f.revision(), before + 1);
      expect(f.effects.calls, 1);
    },
  );

  test(
    'U02-17 recurring committed response loss replays the same accepted projection without duplicate rows or revision',
    () async {
      final f = U02SaveFixture(loseFirstSaveResponseOnce: true);
      await f.open();
      addTearDown(f.close);
      await f.draft(-14400);
      final civil = f.bloc.state.scheduleTime!;
      await f.send(
        ScheduleFormRecurringChanged(
          RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            start: civil,
            timeZoneId: 'America/New_York',
            count: 2,
            repeatedTime: RepeatedCivilTime.first,
          ),
        ),
        (s) => s.recurrenceRule != null,
      );
      final before = await f.revision();
      final mutation = f.bloc.state.mutationId;
      final statuses = <ScheduleFormSubmissionStatus>[];
      final observation = f.bloc.stream
          .map((s) => s.submissionStatus)
          .distinct()
          .listen(statuses.add);
      addTearDown(observation.cancel);
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
      );
      final review = f.bloc.state.recurrenceReview!;
      final selected = <String>{};
      final approved = ScheduleFormRecurrenceReviewConfirmed(
        review,
        excludedSlots: selected,
      );
      // Mutating the caller's set after event construction cannot change approval.
      selected.addAll(review.slots.map((slot) => slot.key));
      await f.send(
        approved,
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.failure,
      );
      final committed = await f.db.select(f.db.schedules).get();
      expect(committed, hasLength(2));
      expect(await f.revision(), before + 1);
      expect(f.effects.calls, 0);
      expect(f.bloc.state.mutationId, mutation);
      expect(f.bloc.state.saveReceipt, isNull);
      // Durable receipt replay precedes current-time validation in the writer.
      f.now = DateTime.utc(2026, 12, 1);
      await f.send(
        ScheduleFormRecurrenceReviewConfirmed(review),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      expect(await f.db.select(f.db.schedules).get(), committed);
      expect(await f.revision(), before + 1);
      expect(f.bloc.state.saveReceipt!.mutationId, mutation);
      expect(f.effects.calls, 1);
      expect(
        statuses.where((s) => s == ScheduleFormSubmissionStatus.review),
        hasLength(1),
      );
    },
  );

  test(
    'U02-17 direct Save cannot bypass review and stale typed confirmations cannot approve a new review or revision',
    () async {
      final f = U02SaveFixture();
      await f.open();
      addTearDown(f.close);
      await f.draft(-14400);
      final civil = f.bloc.state.scheduleTime!;
      await f.send(
        ScheduleFormRecurringChanged(
          RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            start: civil,
            timeZoneId: 'America/New_York',
            count: 2,
            repeatedTime: RepeatedCivilTime.first,
          ),
        ),
        (s) => s.recurrenceRule != null,
      );
      final before = await f.revision();
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
      );
      final first = f.bloc.state.recurrenceReview!;
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
      );
      final second = f.bloc.state.recurrenceReview!;
      expect(identical(first, second), isFalse);
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      f.bloc.add(ScheduleFormRecurrenceReviewConfirmed(first));
      await Future<void>.delayed(Duration.zero);
      await f.db.customSelect('SELECT 1').get();
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      expect(f.bloc.ownsRecurrenceReview(second), isTrue);
      await f.send(
        const ScheduleFormScheduleNameChanged(
          scheduleName: 'Changed after review',
        ),
        (s) => s.scheduleName == 'Changed after review',
      );
      f.bloc.add(ScheduleFormRecurrenceReviewConfirmed(second));
      await Future<void>.delayed(Duration.zero);
      await f.db.customSelect('SELECT 1').get();
      expect(await f.db.select(f.db.schedules).get(), isEmpty);
      expect(await f.revision(), before);
      expect(f.effects.calls, 0);
      await f.send(
        const ScheduleFormCreated(),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.review,
      );
      final fresh = f.bloc.state.recurrenceReview!;
      await f.send(
        ScheduleFormRecurrenceReviewConfirmed(fresh),
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.success,
      );
      final rows = await f.db.select(f.db.schedules).get();
      expect(rows, hasLength(2));
      expect(
        rows.map((row) => row.scheduleName),
        everyElement('Changed after review'),
      );
      expect(await f.revision(), before + 1);
      expect(f.effects.calls, 1);
    },
  );

  testWidgets(
    'U02-16 mixed-zone following draft changes zone through actual review and SQLite commit',
    (tester) async {
      final f = U02SaveFixture();
      await tester.runAsync(f.open);
      await tester.runAsync(() => f.draft(-14400));
      addTearDown(f.close);
      final start = DateTime.utc(2026, 10, 31, 1, 30, 1, 123, 456);
      final base = f.bloc.state
          .createEntity(f.bloc.state)
          .copyWith(scheduleTime: start);
      final prep = f.bloc.state.preparation!;
      await tester.runAsync(
        () => f.recurring.create(
          base,
          prep,
          RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            start: start,
            timeZoneId: 'America/New_York',
            count: 3,
            repeatedTime: RepeatedCivilTime.second,
          ),
        ),
      );
      final initial =
          (await tester.runAsync(
              () => f.db.scheduleDao.getScheduleList(),
            ))!.map((row) => row.toScheduleEntity()).toList()
            ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
      final original = initial[1];
      await tester.runAsync(
        () => f.recurring.updateOccurrence(
          original,
          original.copyWith(
            timeZoneId: 'Asia/Seoul',
            occurrenceOffsetSeconds: 32400,
          ),
          prep,
          preparationChanged: false,
        ),
      );
      // The prefix is now historical and must not move with following edits.
      f.now = DateTime.utc(2026, 10, 31, 13);
      final prefix = await tester.runAsync(
        () => f.db.scheduleDao.getScheduleById(initial.first.id),
      );
      await tester.runAsync(
        () => f.send(
          ScheduleFormEditRequested(
            scheduleId: original.id,
            scope: RecurringEditScope.following,
          ),
          (s) =>
              s.status == ScheduleFormStatus.success &&
              s.originalSchedule != null,
        ),
      );
      expect(f.bloc.state.timeZoneId, 'America/New_York');
      expect(f.bloc.state.originalSchedule!.timeZoneId, 'Asia/Seoul');
      final civil = f.bloc.state.scheduleTime!;
      await tester.runAsync(
        () => f.send(
          ScheduleFormScheduleDateTimeChanged(
            scheduleDate: civil,
            scheduleTime: civil,
            timeZoneId: 'UTC',
            timeZoneExplicitlySelected: true,
            occurrenceOffsetSeconds: 0,
          ),
          (s) => s.timeZoneId == 'UTC',
        ),
      );
      final beforeRevision = await tester.runAsync(f.revision);
      await _mount(tester, f, editing: true);
      await _review(tester, f, editing: true);
      final review = f.bloc.state.recurrenceReview!;
      expect(review.totalOccurrences, 2);
      expect(review.slots, hasLength(2));
      final first = review.occurrences[review.slots.first.key]!;
      expect(first.schedule.timeZoneId, 'Asia/Seoul');
      expect(first.schedule.scheduleTime, civil);
      expect(
        first.preparationStartUtc,
        DateTime.utc(2026, 10, 31, 16, 20, 1, 123, 456),
      );
      expect(
        find.text('Changes: this and following occurrences'),
        findsOneWidget,
      );
      final preview = find.byType(ScheduleZonedTime).first;
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      expect(find.textContaining('Asia/Seoul'), findsWidgets);
      expect(await tester.runAsync(f.revision), beforeRevision);
      await _confirm(tester, f);
      expect(
        await tester.runAsync(
          () => f.db.scheduleDao.getScheduleById(initial.first.id),
        ),
        prefix,
      );
      final rows =
          (await tester.runAsync(
              () => f.db.scheduleDao.getScheduleList(),
            ))!.map((row) => row.toScheduleEntity()).toList()
            ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
      expect(rows, hasLength(3));
      expect(rows[1].timeZoneId, 'Asia/Seoul');
      expect(rows[1].occurrenceOffsetSeconds, 32400);
      expect(rows[2].timeZoneId, 'UTC');
      expect(rows[2].occurrenceOffsetSeconds, 0);
      expect(
        rows[2].scheduleTime,
        DateTime.utc(2026, 11, 2, 1, 30, 1, 123, 456),
      );
      expect(await tester.runAsync(f.revision), beforeRevision! + 1);
      expect(f.effects.calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'U02-17 same-owner recurring input change rejects an open old review and requires a fresh review',
    (tester) async {
      final f = U02SaveFixture();
      await tester.runAsync(f.open);
      await tester.runAsync(() => f.draft(-14400));
      addTearDown(f.close);
      final civil = DateTime.utc(2026, 11, 1, 9);
      await tester.runAsync(
        () => f.send(
          ScheduleFormScheduleDateTimeChanged(
            scheduleDate: civil,
            scheduleTime: civil,
            timeZoneId: 'UTC',
            occurrenceOffsetSeconds: 0,
          ),
          (s) => s.timeZoneId == 'UTC',
        ),
      );
      await tester.runAsync(
        () => f.send(
          ScheduleFormRecurringChanged(
            RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              start: civil,
              timeZoneId: 'UTC',
              count: 2,
            ),
          ),
          (s) => s.recurrenceRule != null,
        ),
      );
      await _mount(tester, f, editing: false);
      final owner = f.bloc.formOwner;
      final beforeRevision = await tester.runAsync(f.revision);
      await _review(tester, f, editing: false);
      final idle = f.bloc.stream.firstWhere(
        (s) => s.submissionStatus == ScheduleFormSubmissionStatus.idle,
      );
      expect(_action('Back').hitTestable(), findsOneWidget);
      await tester.tap(_action('Back'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() => idle.timeout(const Duration(seconds: 5)));
      await tester.pumpAndSettle();
      expect(f.bloc.state.scheduleTime, civil);
      expect(
        await tester.runAsync(() => f.db.select(f.db.schedules).get()),
        isEmpty,
      );
      await tester.runAsync(
        () => f.send(
          ScheduleFormScheduleDateTimeChanged(
            scheduleDate: civil,
            scheduleTime: civil,
            timeZoneId: 'Asia/Seoul',
            occurrenceOffsetSeconds: 32400,
          ),
          (s) => s.timeZoneId == 'Asia/Seoul',
        ),
      );
      await _review(tester, f, editing: false);
      final oldReview = f.bloc.state.recurrenceReview;
      // Same owner, while the real Seoul review is open. The old modal must
      // never approve Tokyo merely because both zones currently have +09:00.
      await tester.runAsync(
        () => f.send(
          ScheduleFormScheduleDateTimeChanged(
            scheduleDate: civil,
            scheduleTime: civil,
            timeZoneId: 'Asia/Tokyo',
            occurrenceOffsetSeconds: 32400,
          ),
          (s) => s.timeZoneId == 'Asia/Tokyo',
        ),
      );
      expect(identical(f.bloc.formOwner, owner), isTrue);
      expect(_action('Save').hitTestable(), findsOneWidget);
      await tester.tap(_action('Save'));
      // Give the actual listener and SQLite queue bounded opportunities; an
      // ignored stale answer may intentionally emit no terminal state.
      for (var attempt = 0; attempt < 10; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
      }
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => f.db.select(f.db.schedules).get()),
        isEmpty,
        reason:
            'An old real modal cannot authorize a different same-owner draft.',
      );
      expect(await tester.runAsync(f.revision), beforeRevision);
      expect(f.effects.calls, 0);
      expect(find.byType(ScheduleMultiPageForm), findsOneWidget);
      expect(f.bloc.state.timeZoneId, 'Asia/Tokyo');
      await _review(tester, f, editing: false);
      expect(identical(f.bloc.state.recurrenceReview, oldReview), isFalse);
      expect(
        f.bloc.state.recurrenceReview!.occurrences.values.map(
          (o) => o.schedule.timeZoneId,
        ),
        everyElement('Asia/Tokyo'),
      );
      await _confirm(tester, f);
      expect(
        await tester.runAsync(() => f.db.select(f.db.schedules).get()),
        hasLength(2),
      );
      expect(await tester.runAsync(f.revision), beforeRevision! + 1);
      expect(f.effects.calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
