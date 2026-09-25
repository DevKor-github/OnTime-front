import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
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
import 'package:on_time_front/presentation/startup/screens/local_data_recovery_screen.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';
import 'package:on_time_front/presentation/my_page/privacy_policy_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import '../../helpers/refresh_capture.dart';

void main() {
  setUpAll(loadRefreshFonts);
  final start = DateTime.utc(2030, 1, 2, 9);
  final rule = RecurrenceRule(
    frequency: RecurrenceFrequency.weekly,
    start: start,
    timeZoneId: 'UTC',
    weekdays: {1, 3, 5},
    count: 10,
  );
  final slots = const RecurrenceEngine()
      .expand(rule, through: DateTime.utc(2031))
      .slots;
  final form = ScheduleFormState(
    scheduleName: '출근 준비',
    scheduleTime: start,
    recurrenceRule: rule,
    preparation: _prep,
    moveTime: const Duration(minutes: 20),
    scheduleSpareTime: const Duration(minutes: 10),
  );

  testWidgets('monthly and end-date controls preserve a valid edited rule', (
    tester,
  ) async {
    await _pump(
      tester,
      RecurrenceSettingsSheet(start: start, timeZoneId: 'UTC', initial: rule),
    );
    await tester.tap(find.widgetWithText(TextButton, '월').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('월 규칙'));
    await tester.pumpAndSettle();
    await captureRefresh(tester, 'monthly');
    await tester.tap(find.text('특정 순번의 요일에 반복'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
    await captureRefresh(tester, 'monthly-fields');
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('총 10회'));
    await tester.pumpAndSettle();
    await captureRefresh(tester, 'ending');
    await tester.tap(find.text('날짜 지정'));
    await tester.pumpAndSettle();
    await captureRefresh(tester, 'end-date');
    expect(find.text('마지막 날짜'), findsOneWidget);
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(find.text('반복 예시'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflicts prohibit excluding every occurrence', (tester) async {
    final review = RecurrenceReview(
      slots: slots.take(3).toList(),
      skipped: [],
      conflicts: [
        RecurrenceConflict(slot: slots.first, other: _schedule('병원 예약', start)),
      ],
    );
    await _pump(tester, RecurrenceReviewSheet(review: review, form: form));
    await captureRefresh(tester, 'conflicts');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(CheckboxListTile).at(i));
      await tester.pump();
    }
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '저장하기 (0개)'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recurring empty state keeps the Figma cards and add action', (
    tester,
  ) async {
    await _pump(tester, RecurringManagementScreen(useCase: _Management([])));

    final info = tester.getRect(find.byKey(const Key('recurring_empty_info')));
    final card = tester.getRect(find.byKey(const Key('recurring_empty_card')));
    final add = tester.getRect(find.byKey(const Key('recurring_empty_add')));
    expect(info.left, 20);
    expect(info.top, 98);
    expect(info.width, 350);
    expect(info.height, greaterThanOrEqualTo(115));
    expect(card.left, 20);
    expect(card.top, inInclusiveRange(269, 273));
    expect(card.width, 350);
    expect(card.height, greaterThanOrEqualTo(122));
    expect(add.left, 20);
    expect(add.top, 749);
    expect(add.width, 350);
    expect(add.height, 47);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/goldens/recurring_empty_390x844.png'),
    );
  });

  testWidgets('secondary recurrence states fit a small phone with large text', (
    tester,
  ) async {
    final screens = <String, Widget>{
      'frequency': RecurrenceSettingsSheet(start: start, timeZoneId: 'UTC'),
      'persistent-conflict': RecurrenceReviewSheet(
        review: RecurrenceReview(
          slots: slots,
          skipped: [],
          persistentConflict: true,
          conflicts: [
            RecurrenceConflict(
              slot: slots.first,
              other: _schedule('아침 운동', start),
            ),
          ],
        ),
        form: form,
      ),
      'detached': RecurrenceReviewSheet(
        review: RecurrenceReview(
          slots: slots,
          skipped: [],
          detached: [_schedule('출근 준비', start)],
        ),
        form: form,
      ),
      'time-exceptions': RecurrenceTimeChoiceSheet(
        date: DateTime(2030, 11, 3, 1, 30),
        timeZoneId: 'America/New_York',
      ),
      'save-error': const RecurrenceSaveErrorSheet(message: '기기에 저장할 수 없어요'),
      'occurrence': RecurrenceOccurrenceSheet(
        schedule: _schedule('출근 준비', DateTime(2025, 9, 23, 10)),
      ),
      'empty': RecurringManagementScreen(useCase: _Management([])),
      'privacy': const PrivacyPolicyScreen(),
      'reset-complete': const LocalDataResetCompleteScreen(),
    };
    for (final entry in screens.entries) {
      await _pump(tester, entry.value);
      await captureRefresh(tester, entry.key);
      expect(tester.takeException(), isNull, reason: entry.key);
      await _pump(tester, entry.value, width: 320, scale: 1.6);
      expect(tester.takeException(), isNull, reason: '${entry.key} large text');
    }
  });

  testWidgets(
    'scope defaults to only this occurrence and supports following scope',
    (tester) async {
      RecurringEditScope? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRecurrenceScope(context);
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await captureRefresh(tester, 'scope');
      await tester.tap(find.text('이번 및 이후 일정'));
      await tester.pump();
      await tester.tap(find.text('선택한 범위로 수정'));
      await tester.pumpAndSettle();
      expect(result, RecurringEditScope.following);
    },
  );

  testWidgets(
    'recovery confirms before deleting and prevents duplicate resets',
    (tester) async {
      final pending = Completer<void>();
      var resets = 0;
      var completed = false;
      await _pump(
        tester,
        LocalDataRecoveryScreen(
          onRetry: () {},
          reset: () {
            resets++;
            return pending.future;
          },
          onResetComplete: () => completed = true,
        ),
      );
      await captureRefresh(tester, 'recovery');
      await tester.tap(find.text('모든 로컬 데이터 초기화'));
      await tester.pumpAndSettle();
      expect(resets, 0);
      await captureRefresh(tester, 'recovery-confirm');
      await tester.tap(find.text('모두 삭제'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(resets, 1);
      expect(find.text('로컬 데이터 초기화 중'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '초기화 실행'))
            .onPressed,
        isNull,
      );
      await captureRefresh(tester, 'recovery-busy');
      pending.complete();
      await tester.pump();
      expect(completed, isTrue);
    },
  );

  testWidgets('failed reset remains recoverable and never reports success', (
    tester,
  ) async {
    await _pump(
      tester,
      LocalDataRecoveryScreen(
        onRetry: () {},
        reset: () async => throw StateError('reset failed'),
        onResetComplete: () => fail('Must not report success'),
      ),
    );
    await tester.tap(find.text('모든 로컬 데이터 초기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모두 삭제'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('초기화하지 못했습니다. 다시 시도해 주세요.'), 200);
    expect(find.text('초기화하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
  });

  testWidgets('privacy keeps all six policy sections scrollable', (
    tester,
  ) async {
    await _pump(tester, const PrivacyPolicyScreen(), width: 320, scale: 1.6);
    expect(PrivacyPolicyScreen.sections, hasLength(6));
    await tester.scrollUntilVisible(find.text('문의'), 300);
    expect(find.text('문의'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'management detail and end confirmation keep independent preparation',
    (tester) async {
      final summary = RecurringScheduleSummary(
        RecurringSegment(
          id: 'segment',
          seriesId: 'series',
          rule: rule,
          schedule: _schedule('출근 준비', start),
          preparation: _prep,
          preparationId: 'own',
          fromSlot: start,
          createdAt: DateTime.utc(2029),
        ),
        _schedule('출근 준비', start),
      );
      await _pump(
        tester,
        RecurringManagementScreen(useCase: _Management([summary])),
      );
      await tester.tap(find.text('출근 준비'));
      await tester.pumpAndSettle();
      await captureRefresh(tester, 'detail');
      expect(find.text('씻기'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('반복 종료').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('반복 종료'));
      await tester.pumpAndSettle();
      await captureRefresh(tester, 'end-confirm');
      expect(find.text('개별로 수정한 이후 회차도 삭제 대상에 포함됩니다.'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
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
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 44, bottom: 34),
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

const _prep = PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'p',
      preparationName: '씻기',
      preparationTime: Duration(minutes: 15),
      nextPreparationId: 'q',
    ),
    PreparationStepEntity(
      id: 'q',
      preparationName: '옷 입기',
      preparationTime: Duration(minutes: 10),
    ),
  ],
);
ScheduleEntity _schedule(String name, DateTime time) => ScheduleEntity(
  id: name,
  place: const PlaceEntity(id: 'p', placeName: '회사'),
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
  @override
  Future<List<RecurringScheduleSummary>> list() async => summaries;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
