import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:on_time_front/presentation/recurring/recurring_management_screen.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

const capture = bool.fromEnvironment('CAPTURE_RECURRING_SCREENSHOTS');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final weight in ['Regular']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.ttf'));
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final start = DateTime.utc(2030, 1, 2, 9);
  RecurrenceRule weekly() => RecurrenceRule(
    frequency: RecurrenceFrequency.weekly,
    start: start,
    timeZoneId: 'UTC',
    weekdays: {1, 3, 5},
    count: 10,
  );

  testWidgets(
    'weekly settings support multiple weekdays and positive count without yearly option',
    (tester) async {
      RecurrenceSettingsResult? result;
      await _pumpRoute(
        tester,
        RecurrenceSettingsSheet(
          start: start,
          timeZoneId: 'UTC',
          initial: weekly(),
        ),
        (value) => result = value as RecurrenceSettingsResult?,
      );
      expect(find.text('매년'), findsNothing);
      expect(
        tester.getSize(find.widgetWithText(TextButton, '화')),
        const Size(44, 44),
      );
      await tester.tap(find.widgetWithText(TextButton, '화'));
      await tester.enterText(find.byType(TextFormField).first, '2');
      await tester.tap(find.text('총 10회'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '7');
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      expect(result!.rule!.weekdays, {1, 2, 3, 5});
      expect(result!.rule!.interval, 2);
      expect(result!.rule!.count, 7);
      expect(result!.countChanged, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty weekday selection stays in the settings sheet', (
    tester,
  ) async {
    await _pumpRoute(
      tester,
      RecurrenceSettingsSheet(
        start: start,
        timeZoneId: 'UTC',
        initial: weekly(),
      ),
      (_) => fail('Invalid rule must not be applied'),
    );
    for (final day in ['월', '수', '금']) {
      await tester.tap(
        find.byKey(
          ValueKey('recurrence-weekday-${{'월': 1, '수': 3, '금': 5}[day]}'),
        ),
      );
    }
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('요일을 하나 이상 선택해 주세요.'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('요일을 하나 이상 선택해 주세요.'), findsOneWidget);
  });

  testWidgets(
    'review requires explicit exclusion and returns only selected conflicting slot',
    (tester) async {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: start,
        timeZoneId: 'UTC',
        count: 3,
      );
      final slots = const RecurrenceEngine()
          .expand(rule, through: DateTime.utc(2031))
          .slots;
      Set<String>? result;
      await _pumpRoute(
        tester,
        RecurrenceReviewSheet(
          review: RecurrenceReview(
            slots: slots,
            skipped: [],
            conflicts: [
              RecurrenceConflict(
                slot: slots[1],
                other: _schedule('Meeting', slots[1].civilTime),
              ),
            ],
          ),
          form: _form(rule),
        ),
        (value) => result = value as Set<String>?,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '저장하기 (3개)'))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile).at(1));
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '저장하기 (2개)'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('저장하기 (2개)'));
      await tester.pumpAndSettle();
      expect(result, {slots[1].key});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'management reads own preparation and confirms ending following scope',
    (tester) async {
      final summary = RecurringScheduleSummary(
        RecurringSegment(
          id: 'segment',
          seriesId: 'series',
          rule: weekly(),
          schedule: _schedule('출근 준비', start),
          preparation: _prep,
          preparationId: 'own',
          fromSlot: start,
          createdAt: DateTime.utc(2029),
        ),
        _schedule('출근 준비', start),
      );
      final useCase = _Management([summary]);
      final boundary = GlobalKey();
      await _pump(
        tester,
        RecurringManagementScreen(useCase: useCase),
        boundary: boundary,
      );
      await _capture(tester, boundary, 'management');
      await tester.pumpAndSettle();
      await tester.tap(find.text('출근 준비'));
      await tester.pumpAndSettle();
      expect(find.text('가방 챙기기'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('반복 종료'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('반복 종료'));
      await tester.pumpAndSettle();
      expect(useCase.deleted, isNull);
      await tester.tap(find.widgetWithText(TextButton, '약속 삭제'));
      await tester.pumpAndSettle();
      expect(useCase.deleted, RecurringEditScope.following);
      await tester.tap(find.widgetWithText(TextButton, '확인'));
      await tester.pumpAndSettle();
      expect(find.text('예정된 회차 없음'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings and review render at phone width and large text', (
    tester,
  ) async {
    final key = GlobalKey();
    await _pump(
      tester,
      RecurrenceSettingsSheet(
        start: start,
        timeZoneId: 'UTC',
        initial: weekly(),
      ),
      boundary: key,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, key, 'weekly');
    final rule = weekly();
    final slots = const RecurrenceEngine()
        .expand(rule, through: DateTime.utc(2032))
        .slots;
    final review = RecurrenceReview(
      slots: slots,
      skipped: [],
      totalOccurrences: 10,
      occurrences: {
        for (final slot in slots)
          slot.key: RecurrencePreviewOccurrence(
            _schedule('출근 준비', slot.civilTime),
            slot.instantUtc.subtract(const Duration(minutes: 55)),
          ),
      },
    );
    await _pump(
      tester,
      RecurrenceReviewSheet(review: review, form: _form(rule)),
      boundary: key,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, key, 'review');
    await _pump(
      tester,
      RecurrenceSettingsSheet(
        start: start,
        timeZoneId: 'UTC',
        initial: weekly(),
      ),
      textScale: 1.6,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _pump(
      tester,
      RecurrenceReviewSheet(review: review, form: _form(rule)),
      textScale: 1.6,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _pump(
      tester,
      RecurrenceSettingsSheet(
        start: start,
        timeZoneId: 'UTC',
        initial: RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
          start: start,
          timeZoneId: 'UTC',
          monthly: MonthlyRecurrence.nthWeekday,
          ordinal: -1,
          monthWeekday: 5,
        ),
      ),
      boundary: key,
    );
    await _capture(tester, key, 'monthly');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  GlobalKey? boundary,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeData,
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 44, bottom: 34),
          ),
          child: child!,
        ),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRoute(
  WidgetTester tester,
  Widget screen,
  void Function(Object?) result,
) async {
  await _pump(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final value = await Navigator.of(context).push<Object?>(
            MaterialPageRoute(builder: (context) => Scaffold(body: screen)),
          );
          result(value);
        },
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!capture) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory(
      'docs/design/redesign-20260923/flutter/screenshots',
    )..createSync(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

ScheduleFormState _form(RecurrenceRule rule) => ScheduleFormState(
  scheduleName: '출근 준비',
  scheduleTime: rule.start,
  recurrenceRule: rule,
  preparation: _prep,
  moveTime: const Duration(minutes: 20),
  scheduleSpareTime: const Duration(minutes: 10),
);
const _prep = PreparationEntity(
  preparationStepList: [
    PreparationStepEntity(
      id: 'p',
      preparationName: '가방 챙기기',
      preparationTime: Duration(minutes: 25),
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
);

class _Management implements RecurringSchedulesUseCase {
  _Management(this.summaries);
  List<RecurringScheduleSummary> summaries;
  RecurringEditScope? deleted;
  @override
  DeleteScheduleUseCase get deletions => _ManagementDeletion(this);
  @override
  Future<List<RecurringScheduleSummary>> list() async => summaries;
  @override
  Future<ScheduleDeletionResult> delete(
    ScheduleEntity occurrence,
    RecurringEditScope scope,
  ) async {
    deleted = scope;
    summaries = [RecurringScheduleSummary(summaries.first.segment, null)];
    return ScheduleDeletionResult(
      commit: ScheduleDeletionCommit(
        scheduleId: occurrence.id,
        store: 'ui',
        generation: 0,
        removedIds: {occurrence.id},
        changed: true,
        alreadyAbsent: false,
      ),
      cleanup: ScheduleDeletionCleanup.complete,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ManagementDeletion extends Fake implements DeleteScheduleUseCase {
  _ManagementDeletion(this.management);
  final _Management management;
  @override
  int get currentGeneration => 0;
  @override
  bool isCurrentGeneration(int generation) => generation == 0;
  @override
  Future<ScheduleDeletionIntent> prepare(
    String id, {
    RecurringEditScope scope = RecurringEditScope.occurrence,
  }) async => ScheduleDeletionIntent(
    intentId: 'ui',
    scope: scope,
    targets: [],
    snapshot: ScheduleEditSnapshot(
      management.summaries.first.next!,
      _prep,
      const ScheduleEditBaseline(store: 'ui', generation: 0, revision: 0),
    ),
  );
  @override
  Future<ScheduleDeletionResult> confirm(
    ScheduleDeletionIntent intent, {
    void Function(ScheduleDeletionCommit)? onCommitted,
  }) async {
    final result = await management.delete(
      intent.snapshot.schedule,
      intent.scope,
    );
    onCommitted?.call(result.commit);
    return result;
  }
}
