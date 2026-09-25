import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_time_correction.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurring_time_correction_plan_summary.dart';

ScheduleEntity _schedule(String id, {bool override = false}) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'place', placeName: 'Office'),
  scheduleName: 'Appointment $id',
  scheduleTime: DateTime.utc(2030, 1, 3, override ? 11 : 9),
  timeZoneId: override ? 'Asia/Seoul' : 'UTC',
  occurrenceOffsetSeconds: override ? 32400 : 0,
  isChanged: false,
  isStarted: false,
  moveTime: Duration.zero,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
  recurringSegmentId: 'old-segment',
  recurringOrdinal: 3,
  recurringSlotKey: DateTime.utc(2030, 1, 3, 9).toIso8601String(),
  recurringOverrides: override ? 'time' : '',
);

RecurrenceSlot _slot(int ordinal) => RecurrenceSlot(
  civilTime: DateTime.utc(2030, 1, ordinal, 9),
  instantUtc: DateTime.utc(2030, 1, ordinal, 9),
  offsetSeconds: 0,
  ordinal: ordinal,
);

RecurringTimeCorrectionMapping _mapping({int? many}) =>
    RecurringTimeCorrectionMapping(
      rule: RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: DateTime.utc(2030, 1, 1, 9),
        timeZoneId: 'UTC',
        count: many ?? 5,
      ),
      automaticallyRetainedCount: true,
      rows: many != null
          ? [
              for (var i = 1; i <= many; i++)
                TimeCorrectionRowMapping(_schedule('row-$i'), _slot(i)),
            ]
          : [
              TimeCorrectionRowMapping(_schedule('mapped'), _slot(2)),
              TimeCorrectionRowMapping(
                _schedule('override', override: true),
                _slot(3),
              ),
              TimeCorrectionRowMapping(_schedule('detached'), null),
            ],
      protectedRows: many != null
          ? []
          : [
              _schedule(
                'protected',
              ).copyWith(doneStatus: ScheduleDoneStatus.normalEnd),
            ],
      exclusions: many != null
          ? []
          : [
              TimeCorrectionExclusionMapping(
                TimeCorrectionExclusion(
                  'old-segment',
                  DateTime.utc(2030, 1, 4, 9).toIso8601String(),
                  4,
                ),
                _slot(4),
              ),
              TimeCorrectionExclusionMapping(
                TimeCorrectionExclusion(
                  'old-segment',
                  DateTime.utc(2030, 1, 5, 9).toIso8601String(),
                  5,
                ),
                null,
              ),
            ],
      protectedSlots: many != null ? [] : [_slot(1)],
      firstSlot: _slot(1),
      workUnits: 0,
    );

Widget _app(Widget child, {String locale = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final locale in ['ko', 'en']) {
    testWidgets('$locale plan remains readable at 320px and 2.5 text scaling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          RecurringTimeCorrectionPlanSummary(
            mapping: _mapping(),
            unresolvedOverrides: const {
              'override': ScheduleTimeResolutionStatus.ambiguous,
            },
            confirmedDetachedIds: const {},
            confirmedUnmatchedExclusions: const {},
            onDetachedChanged: (_) {},
            onUnmatchedExclusionsChanged: (_) {},
            onResolveOverride: (_) {},
          ),
          locale: locale,
          scale: 2.5,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          locale == 'ko' ? '반복 일정 변경 내용' : 'Recurring schedule changes',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          locale == 'ko'
              ? '과거 시간대 규칙을 재현'
              : 'does not reconstruct historical time-zone rules',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const Key('plan-unmatched-exclusions')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'mapped time override is not presented as the new slot appointment instant',
    (tester) async {
      await tester.pumpWidget(
        _app(
          RecurringTimeCorrectionPlanSummary(
            mapping: _mapping(),
            unresolvedOverrides: const {},
            confirmedDetachedIds: const {},
            confirmedUnmatchedExclusions: const {},
            onDetachedChanged: (_) {},
            onUnmatchedExclusionsChanged: (_) {},
          ),
        ),
      );
      final override = find.byKey(const ValueKey('mapped-override'));
      final value = tester
          .widget<Text>(
            find.descendant(of: override, matching: find.byType(Text)).last,
          )
          .data!;
      expect(value, contains('Asia/Seoul'));
      expect(value, contains('+09:00'));
      expect(
        value,
        contains(
          'individually chosen appointment time and zone stay unchanged',
        ),
      );
      expect(value, isNot(contains('New appointment instant')));
      final moved = tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('mapped-mapped')),
                  matching: find.byType(Text),
                )
                .last,
          )
          .data!;
      expect(
        moved,
        contains('New appointment instant: 2030-01-02T09:00:00.000Z'),
      );
      expect(moved, contains('Original slot:'));
    },
  );

  testWidgets(
    'standalone and unmatched exclusion acknowledgement sets stay separate and exact',
    (tester) async {
      final mapping = _mapping();
      var detached = <String>{'outside-this-plan'};
      var exclusions = <String>{'old-review-only'};
      var detachedChanges = 0;
      var exclusionChanges = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => RecurringTimeCorrectionPlanSummary(
              mapping: mapping,
              unresolvedOverrides: const {},
              confirmedDetachedIds: detached,
              confirmedUnmatchedExclusions: exclusions,
              onDetachedChanged: (value) {
                detachedChanges++;
                setState(() => detached = value);
              },
              onUnmatchedExclusionsChanged: (value) {
                exclusionChanges++;
                setState(() => exclusions = value);
              },
            ),
          ),
        ),
      );
      Finder checkbox(Key key) =>
          find.descendant(of: find.byKey(key), matching: find.byType(Checkbox));
      final standalone = checkbox(const ValueKey('detached-detached'));
      await tester.ensureVisible(standalone);
      await tester.tap(standalone.hitTestable());
      await tester.pumpAndSettle();
      expect(detached, {'detached'});
      expect(detachedChanges, 1);
      expect(exclusionChanges, 0);
      expect(() => detached.add('illegal'), throwsUnsupportedError);
      final key = RecurringTimeCorrectionPlanSummary.exclusionKey(
        mapping.exclusions.last.original,
      );
      final exclusion = checkbox(ValueKey('exclusion-$key'));
      await tester.ensureVisible(exclusion);
      await tester.tap(exclusion.hitTestable());
      await tester.pumpAndSettle();
      expect(exclusions, {key});
      expect(detached, {'detached'});
      expect(exclusionChanges, 1);
      await tester.ensureVisible(standalone);
      await tester.tap(standalone.hitTestable());
      await tester.pumpAndSettle();
      expect(detached, isEmpty);
      expect(exclusions, {key});
    },
  );

  testWidgets(
    'individual override review dispatches its stable schedule ID without acknowledging anything',
    (tester) async {
      final resolved = <String>[];
      var acknowledgements = 0;
      await tester.pumpWidget(
        _app(
          RecurringTimeCorrectionPlanSummary(
            mapping: _mapping(),
            unresolvedOverrides: const {
              'override': ScheduleTimeResolutionStatus.changed,
            },
            confirmedDetachedIds: const {},
            confirmedUnmatchedExclusions: const {},
            onDetachedChanged: (_) => acknowledgements++,
            onUnmatchedExclusionsChanged: (_) => acknowledgements++,
            onResolveOverride: resolved.add,
          ),
        ),
      );
      final action = find.byKey(const ValueKey('resolve-override'));
      expect(
        find.widgetWithText(TextButton, 'Review this time'),
        findsOneWidget,
      );
      await tester.ensureVisible(action);
      await tester.tap(action.hitTestable());
      await tester.pumpAndSettle();
      expect(resolved, ['override']);
      expect(acknowledgements, 0);
      expect(
        find.textContaining('Conflict review is separate'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'disabled plan cannot change acknowledgements or launch another review',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        _app(
          RecurringTimeCorrectionPlanSummary(
            mapping: _mapping(),
            unresolvedOverrides: const {
              'override': ScheduleTimeResolutionStatus.unknownZone,
            },
            confirmedDetachedIds: const {},
            confirmedUnmatchedExclusions: const {},
            enabled: false,
            onDetachedChanged: (_) => changes++,
            onUnmatchedExclusionsChanged: (_) => changes++,
            onResolveOverride: (_) => changes++,
          ),
        ),
      );
      final action = find.byKey(const ValueKey('resolve-override'));
      expect(
        find.widgetWithText(TextButton, 'Review this time'),
        findsOneWidget,
      );
      await tester.ensureVisible(action);
      await tester.tap(action.hitTestable());
      final checkbox = find.descendant(
        of: find.byKey(const ValueKey('detached-detached')),
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox.hitTestable());
      await tester.pumpAndSettle();
      expect(changes, 0);
    },
  );

  testWidgets(
    'large plans render one page per section and reset the page for a new plan',
    (tester) async {
      final first = _mapping(many: 25);
      Widget plan(RecurringTimeCorrectionMapping mapping) => _app(
        RecurringTimeCorrectionPlanSummary(
          mapping: mapping,
          unresolvedOverrides: const {},
          confirmedDetachedIds: const {},
          confirmedUnmatchedExclusions: const {},
          onDetachedChanged: (_) {},
          onUnmatchedExclusionsChanged: (_) {},
        ),
      );
      await tester.pumpWidget(plan(first));
      expect(find.byType(ListTile), findsNWidgets(10));
      expect(find.text('Appointment row-1'), findsOneWidget);
      expect(find.text('Appointment row-11'), findsNothing);
      final next = find.byKey(const Key('plan-page-next'));
      await tester.ensureVisible(next);
      await tester.tap(next.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(10));
      expect(find.text('Appointment row-1'), findsNothing);
      expect(find.text('Appointment row-11'), findsOneWidget);
      await tester.pumpWidget(plan(_mapping(many: 25)));
      await tester.pumpAndSettle();
      expect(find.text('Appointment row-1'), findsOneWidget);
      expect(find.text('Appointment row-11'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
