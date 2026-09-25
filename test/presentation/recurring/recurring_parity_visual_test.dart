import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/use-cases/recurring_schedules_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurrence_settings_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_review_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_scope_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_time_choice_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_occurrence_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurring_management_screen.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import '../../helpers/refresh_capture.dart';

void main() {
  setUpAll(loadRefreshFonts);
  final start = DateTime.utc(2026, 9, 23, 9);
  final now = DateTime.utc(2026, 9, 22);
  RecurrenceRule weekly({int? count, DateTime? until}) => RecurrenceRule(
    frequency: RecurrenceFrequency.weekly,
    start: start,
    timeZoneId: 'UTC',
    weekdays: {1, 3, 5},
    count: count,
    until: until,
  );
  ScheduleFormState form(RecurrenceRule rule) => ScheduleFormState(
    scheduleName: '출근 준비',
    scheduleTime: start,
    recurrenceRule: rule,
    preparation: _preparation,
    moveTime: const Duration(minutes: 20),
    scheduleSpareTime: const Duration(minutes: 10),
  );

  testWidgets('weekly settings visual reference preserves weekday controls', (
    tester,
  ) async {
    await _pump(
      tester,
      RecurrenceSettingsSheet(
        start: start,
        timeZoneId: 'UTC',
        initial: weekly(),
        now: () => now,
      ),
    );
    await _golden(tester, 'weekly');
    expect(
      tester.getSize(find.widgetWithText(TextButton, '수')),
      const Size(44, 44),
    );
  });

  testWidgets(
    'monthly overview and ordinal fields keep independent selections',
    (tester) async {
      await _pump(
        tester,
        RecurrenceSettingsSheet(
          start: start,
          timeZoneId: 'UTC',
          initial: weekly(),
          now: () => now,
        ),
      );
      await tester.tap(find.widgetWithText(TextButton, '월').first);
      await tester.pumpAndSettle();
      await _golden(tester, 'monthly');
      await tester.tap(find.text('월 규칙'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('특정 순번의 요일에 반복'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2번째').last);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _golden(tester, 'monthly_fields');
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
    },
  );

  testWidgets('ending count and inclusive end date visual references', (
    tester,
  ) async {
    await _pump(
      tester,
      RecurrenceSettingsSheet(
        start: start,
        timeZoneId: 'UTC',
        initial: weekly(count: 10),
        now: () => now,
      ),
    );
    await tester.tap(find.text('총 10회'));
    await tester.pumpAndSettle();
    await _golden(tester, 'ending');
    await _pump(
      tester,
      RecurrenceSettingsSheet(
        start: start,
        timeZoneId: 'UTC',
        initial: weekly(until: DateTime.utc(2026, 12, 31)),
        now: () => now,
      ),
    );
    await tester.tap(find.text('2026년 12월 31일'));
    await tester.pumpAndSettle();
    await _golden(tester, 'end_date');
    expect(find.text('마지막 날짜'), findsOneWidget);
  });

  testWidgets('frequency visual reference shows selected daily interval', (
    tester,
  ) async {
    await _pump(
      tester,
      RecurrenceSettingsSheet(start: start, timeZoneId: 'UTC', now: () => now),
    );
    await tester.tap(find.text('매일'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _golden(tester, 'frequency');
  });

  testWidgets(
    'review includes first actual date and excluded past preparation',
    (tester) async {
      final rule = weekly();
      final expanded = const RecurrenceEngine().expand(
        rule,
        through: DateTime.utc(2026, 10),
        preparationNotBeforeUtc: DateTime.utc(2026, 9, 23, 8, 30),
        leadTime: const Duration(minutes: 55),
        limit: 3,
      );
      final review = RecurrenceReview(
        slots: expanded.slots,
        skipped: expanded.skipped,
        occurrences: {
          for (final slot in expanded.slots)
            slot.key: RecurrencePreviewOccurrence(
              _schedule(slot.civilTime),
              slot.instantUtc.subtract(const Duration(minutes: 55)),
            ),
        },
      );
      await _pump(
        tester,
        RecurrenceReviewSheet(review: review, form: form(rule)),
      );
      expect(find.textContaining('9월 25일'), findsWidgets);
      expect(find.textContaining('준비 시작 시각이 지남'), findsOneWidget);
      await _golden(tester, 'review');
    },
  );

  testWidgets(
    'conflict golden follows explicit exclusions and prevents empty save',
    (tester) async {
      final rule = weekly(count: 10);
      final slots = const RecurrenceEngine()
          .expand(rule, through: DateTime.utc(2027))
          .slots;
      final review = RecurrenceReview(
        slots: slots,
        skipped: [],
        conflicts: [
          RecurrenceConflict(
            slot: slots[1],
            other: _schedule(slots[1].civilTime, name: '병원 예약'),
          ),
          RecurrenceConflict(
            slot: slots[2],
            other: _schedule(slots[2].civilTime, name: '아침 모임'),
          ),
        ],
      );
      await _pump(
        tester,
        RecurrenceReviewSheet(review: review, form: form(rule)),
      );
      for (final index in [1, 2]) {
        await tester.tap(find.byType(CheckboxListTile).at(index));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '저장하기 (8개)'))
            .onPressed,
        isNotNull,
      );
      await _golden(tester, 'conflicts');
    },
  );

  testWidgets('persistent conflict cannot save and shows runtime time ranges', (
    tester,
  ) async {
    final rule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      start: start,
      timeZoneId: 'UTC',
      weekdays: {3},
    );
    final slots = const RecurrenceEngine()
        .expand(rule, through: DateTime.utc(2026, 10))
        .slots;
    final other = _schedule(
      DateTime.utc(2026, 9, 23, 9, 30),
      name: '아침 운동',
    ).copyWith(moveTime: const Duration(minutes: 90));
    await _pump(
      tester,
      RecurrenceReviewSheet(
        review: RecurrenceReview(
          slots: slots,
          skipped: [],
          persistentConflict: true,
          conflicts: [RecurrenceConflict(slot: slots.first, other: other)],
        ),
        form: form(rule),
      ),
    );
    await _golden(tester, 'persistent_conflict');
    expect(find.text('저장하기'), findsNothing);
  });

  testWidgets('detached schedule preserves actual override time', (
    tester,
  ) async {
    final rule = weekly();
    await _pump(
      tester,
      RecurrenceReviewSheet(
        review: RecurrenceReview(
          slots: [],
          skipped: [],
          detached: [_schedule(DateTime.utc(2026, 9, 30, 10))],
        ),
        form: form(rule),
      ),
    );
    await _golden(tester, 'detached');
    expect(find.text('오전 10:00'), findsOneWidget);
  });

  testWidgets('scope choice and selected following scope are interactive', (
    tester,
  ) async {
    RecurringEditScope? result;
    await _pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              result = await showRecurrenceScope(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _golden(tester, 'scope');
    await tester.tap(find.text('이번 및 이후 일정'));
    await tester.tap(find.text('선택한 범위로 수정'));
    await tester.pumpAndSettle();
    expect(result, RecurringEditScope.following);
  });

  testWidgets('repeated civil time exposes real UTC offsets', (tester) async {
    await _pump(
      tester,
      RecurrenceTimeChoiceSheet(
        date: DateTime(2026, 11, 1, 1, 30),
        timeZoneId: 'America/New_York',
      ),
    );
    expect(find.textContaining('UTC-04:00'), findsOneWidget);
    expect(find.textContaining('UTC-05:00'), findsOneWidget);
    await _golden(tester, 'time_exceptions');
    await tester.tap(find.text('두 번째 1:30'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'storage failure shows actual error without a fabricated empty result',
    (tester) async {
      await _pump(
        tester,
        const RecurrenceSaveErrorSheet(message: '기기에 저장할 수 없어요'),
      );
      await _golden(tester, 'save_error');
      expect(find.text('조건에 맞는 일정이 없어요'), findsNothing);
    },
  );

  testWidgets('occurrence keeps edit delete and no-history information', (
    tester,
  ) async {
    await _pump(
      tester,
      RecurrenceOccurrenceSheet(
        schedule: _schedule(
          DateTime.utc(2026, 9, 23, 10),
        ).copyWith(recurringOverrides: 'time'),
        now: () => DateTime.utc(2026, 9, 25),
        onEdit: () {},
        onDelete: () {},
      ),
    );
    await _golden(tester, 'occurrence');
    expect(find.text('진행 기록이 없습니다.'), findsOneWidget);
    expect(find.text('이 회차 삭제하기'), findsOneWidget);
    await _pump(
      tester,
      RecurrenceOccurrenceSheet(
        schedule: _schedule(DateTime.utc(2026, 9, 23, 10, 45)),
      ),
    );
    expect(find.text('9/23 수요일 10시 45분'), findsOneWidget);
  });

  testWidgets('detail and end confirmation preserve next occurrence boundary', (
    tester,
  ) async {
    final summary = RecurringScheduleSummary(
      RecurringSegment(
        id: 'segment',
        seriesId: 'series',
        rule: weekly(),
        schedule: _schedule(start),
        preparation: _preparation,
        preparationId: 'own',
        fromSlot: start,
        createdAt: now,
      ),
      _schedule(DateTime.utc(2026, 9, 25, 9)),
    );
    final useCase = _Management([summary]);
    await _pump(tester, RecurringManagementScreen(useCase: useCase));
    await tester.tap(find.text('출근 준비'));
    await tester.pumpAndSettle();
    await _golden(tester, 'detail');
    await tester.scrollUntilVisible(
      find.text('반복 종료').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('반복 종료'));
    await tester.pumpAndSettle();
    await _golden(tester, 'end_confirm');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(useCase.deletes, 0);
  });
}

Future<void> _golden(WidgetTester tester, String state) async {
  expect(tester.takeException(), isNull, reason: state);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/goldens/recurring_${state}_390x844.png'),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: themeData,
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: const EdgeInsets.only(top: 44, bottom: 34)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

const _preparation = PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'wash',
      preparationName: '씻기',
      preparationTime: Duration(minutes: 15),
      nextPreparationId: 'dress',
    ),
    PreparationStepEntity(
      id: 'dress',
      preparationName: '옷입기',
      preparationTime: Duration(minutes: 10),
    ),
  ],
);
ScheduleEntity _schedule(DateTime time, {String name = '출근 준비'}) =>
    ScheduleEntity(
      id: name,
      place: const PlaceEntity(id: 'company', placeName: '회사'),
      scheduleName: name,
      scheduleTime: time,
      timeZoneId: 'UTC',
      occurrenceOffsetSeconds: 0,
      moveTime: Duration.zero,
      isChanged: true,
      isStarted: false,
      scheduleSpareTime: Duration.zero,
      scheduleNote: '',
      recurringSegmentId: 'segment',
    );

class _Management implements RecurringSchedulesUseCase {
  _Management(this.summaries);
  final List<RecurringScheduleSummary> summaries;
  int deletes = 0;
  @override
  Future<List<RecurringScheduleSummary>> list() async => summaries;
  @override
  Future<void> delete(ScheduleEntity schedule, RecurringEditScope scope) async {
    deletes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
