import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurrence_review_sheet.dart';
import 'package:on_time_front/presentation/recurring/recurrence_time_choice_sheet.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_form_bloc.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_scope.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';

ScheduleEntity _schedule(String id, DateTime civil) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'p', placeName: 'Synthetic place'),
  scheduleName: id,
  scheduleTime: civil,
  timeZoneId: 'Asia/Seoul',
  occurrenceOffsetSeconds: 32400,
  moveTime: Duration.zero,
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: Duration.zero,
  scheduleNote: '',
);

Future<void> _mount(WidgetTester tester, Widget child, String language) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = DeviceTimeZoneController(
    readZone: () async => 'America/New_York',
  );
  await controller.refresh();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  await tester.pumpWidget(
    DeviceTimeZoneScope(
      controller: controller,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2.5),
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
}

void main() {
  final rule = RecurrenceRule(
    frequency: RecurrenceFrequency.daily,
    start: DateTime.utc(2030, 1, 2, 9),
    timeZoneId: 'Asia/Seoul',
    count: 5,
  );
  final slots = const RecurrenceEngine()
      .expand(rule, through: DateTime.utc(2031))
      .slots;
  final occurrences = {
    for (final slot in slots)
      slot.key: RecurrencePreviewOccurrence(
        _schedule('slot-${slot.ordinal}', slot.civilTime),
        slot.instantUtc.subtract(const Duration(minutes: 10)),
      ),
  };
  final form = ScheduleFormState(
    id: 'draft',
    scheduleName: 'Synthetic recurring appointment',
    scheduleTime: rule.start,
    timeZoneId: rule.timeZoneId,
    occurrenceOffsetSeconds: 32400,
    moveTime: Duration.zero,
    scheduleSpareTime: Duration.zero,
    recurrenceRule: rule,
  );

  for (final language in ['ko', 'en']) {
    testWidgets(
      '$language recurring review exposes every reviewed occurrence and preparation at320 text2.5',
      (tester) async {
        await _mount(
          tester,
          RecurrenceReviewSheet(
            review: RecurrenceReview(
              slots: slots,
              skipped: [],
              occurrences: occurrences,
              totalOccurrences: 5,
            ),
            form: form,
          ),
          language,
        );
        expect(tester.takeException(), isNull);
        await _reveal(
          tester,
          find.textContaining(slots.first.instantUtc.toIso8601String()),
        );
        final first = tester.widgetList<ScheduleZonedTime>(
          find.byType(ScheduleZonedTime),
        );
        expect(
          first.any((w) => w.resolution.instantUtc == slots.first.instantUtc),
          isTrue,
        );
        expect(
          first.any(
            (w) =>
                w.resolution.instantUtc ==
                occurrences[slots.first.key]!.preparationStartUtc,
          ),
          isTrue,
        );
        final all = find.byKey(const ValueKey('all-reviewed-occurrences'));
        await _reveal(tester, all);
        await tester.tap(all);
        await tester.pumpAndSettle();
        final lastInstant = find.textContaining(
          slots.last.instantUtc.toIso8601String(),
        );
        await _reveal(tester, lastInstant);
        expect(find.textContaining('America/New_York'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language repeated-time choices expose both exact UTC instants at320 text2.5',
      (tester) async {
        await _mount(
          tester,
          RecurrenceTimeChoiceSheet(
            date: DateTime.utc(2030, 11, 3, 1, 30),
            timeZoneId: 'America/New_York',
          ),
          language,
        );
        expect(tester.takeException(), isNull);
        for (final instant in [
          DateTime.utc(2030, 11, 3, 5, 30),
          DateTime.utc(2030, 11, 3, 6, 30),
        ]) {
          await _reveal(tester, find.textContaining(instant.toIso8601String()));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'conflict review retains each selectable real zone and occurrence',
    (tester) async {
      final conflict = _schedule('conflicting appointment', slots[1].civilTime);
      await _mount(
        tester,
        RecurrenceReviewSheet(
          review: RecurrenceReview(
            slots: slots,
            skipped: [],
            occurrences: occurrences,
            conflicts: [RecurrenceConflict(slot: slots[1], other: conflict)],
          ),
          form: form,
        ),
        'en',
      );
      expect(tester.takeException(), isNull);
      final checkbox = find.byKey(
        ValueKey('review-occurrence-${slots[1].key}'),
      );
      await tester.scrollUntilVisible(
        checkbox,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<ScheduleZonedTime>(
        find.descendant(of: checkbox, matching: find.byType(ScheduleZonedTime)),
      );
      expect(preview.timeZoneId, 'Asia/Seoul');
      expect(preview.resolution.instantUtc, slots[1].instantUtc);
    },
  );
  testWidgets('detached review preserves its original zone and exact instant', (
    tester,
  ) async {
    final detached = _schedule(
      'Detached original',
      DateTime.utc(2030, 1, 9, 9),
    );
    await _mount(
      tester,
      RecurrenceReviewSheet(
        review: RecurrenceReview(
          slots: const [],
          skipped: const [],
          detached: [detached],
        ),
        form: form,
      ),
      'en',
    );
    expect(tester.takeException(), isNull);
    final time = find.textContaining(
      detached.occurrenceInstantUtc.toIso8601String(),
    );
    await _reveal(tester, time);
    expect(find.textContaining('Asia/Seoul'), findsOneWidget);
    expect(find.textContaining('America/New_York'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'obsolete explicit draft offset remains changed in persistent conflict preview',
    (tester) async {
      await _mount(
        tester,
        RecurrenceReviewSheet(
          review: RecurrenceReview(
            slots: slots,
            skipped: const [],
            persistentConflict: true,
          ),
          form: form.copyWith(occurrenceOffsetSeconds: 0),
        ),
        'en',
      );
      final preview = find.byType(ScheduleZonedTime);
      await tester.scrollUntilVisible(
        preview,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final widget = tester.widget<ScheduleZonedTime>(preview);
      expect(widget.resolution.status, ScheduleTimeResolutionStatus.changed);
      expect(widget.resolution.instantUtc, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final zone in ['UTC', 'Removed/Zone']) {
    testWidgets(
      'preparation preview handles $zone rule/range failure without replacing its reviewed instant',
      (tester) async {
        final original = _schedule(
          'Boundary commitment',
          DateTime.utc(1),
        ).copyWith(timeZoneId: zone, occurrenceOffsetSeconds: 0);
        final slot = RecurrenceSlot(
          civilTime: DateTime.utc(1),
          instantUtc: DateTime.utc(1),
          offsetSeconds: 0,
          ordinal: 1,
        );
        final preparation = DateTime.utc(0, 12, 31, 23);
        await _mount(
          tester,
          RecurrenceReviewSheet(
            review: RecurrenceReview(
              slots: [slot],
              skipped: const [],
              occurrences: {
                slot.key: RecurrencePreviewOccurrence(original, preparation),
              },
            ),
            form: form,
          ),
          'en',
        );
        expect(tester.takeException(), isNull);
        final warning = find.textContaining(
          'preparation start cannot be displayed',
        );
        await _reveal(tester, warning);
        expect(
          find.textContaining(preparation.toIso8601String()),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
