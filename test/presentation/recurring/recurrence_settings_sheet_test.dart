import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/recurring/recurrence_settings_sheet.dart';

class _Result {
  bool completed = false;
  RecurrenceSettingsResult? value;
}

Future<_Result> _open(WidgetTester tester, RecurrenceRule rule) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result.value = await Navigator.of(context)
                  .push<RecurrenceSettingsResult>(
                    MaterialPageRoute(
                      builder: (_) => RecurrenceSettingsSheet(
                        start: rule.start,
                        timeZoneId: rule.timeZoneId,
                        initial: rule,
                      ),
                    ),
                  );
              result.completed = true;
            },
            child: const Text('Open recurrence'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open recurrence'));
  await tester.pumpAndSettle();
  return result;
}

Future<void> _ending(WidgetTester tester) async {
  final setting = find.byWidgetPredicate(
    (widget) => widget is RecurrenceValue && widget.label == 'Repeat ends',
  );
  await tester.ensureVisible(setting);
  await tester.tap(setting);
  await tester.pumpAndSettle();
  await tester.tap(find.text('On date'));
  await tester.pumpAndSettle();
}

Future<void> _datePicker(WidgetTester tester) async {
  final date = find.text('Inclusive end date');
  await tester.ensureVisible(date);
  await tester.tap(date);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String wheel, int index) async {
  final picker = tester.widget<CupertinoPicker>(
    find.byKey(ValueKey('civil-picker-$wheel')),
  );
  picker.scrollController!.jumpToItem(index);
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('civil-picker-confirm')));
  await tester.pumpAndSettle();
}

Future<void> _applyEnding(WidgetTester tester) async {
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
}

RecurrenceRule _daily(DateTime start, {DateTime? until}) => RecurrenceRule(
  frequency: RecurrenceFrequency.daily,
  start: start,
  timeZoneId: 'UTC',
  until: until,
);

void main() {
  testWidgets('default inclusive end remains December 30 on an Apia device', (
    tester,
  ) async {
    if (Platform.environment['TZ'] == 'Pacific/Apia') {
      expect(
        DateTime(2011, 12, 30).day,
        isNot(30),
        reason: 'Exercise the actual skipped date in the device timezone',
      );
    }
    final result = await _open(tester, _daily(DateTime.utc(2011, 9, 30, 9)));
    await _ending(tester);
    expect(find.text('Dec 30, 2011'), findsOneWidget);
    expect(result.completed, isFalse);
    await _applyEnding(tester);
    expect(result.value!.rule!.until, DateTime.utc(2011, 12, 30));
    expect(result.value!.rule!.start, DateTime.utc(2011, 9, 30, 9));
  });

  testWidgets(
    'default end near year 9999 stops at the last supported civil date',
    (tester) async {
      final result = await _open(tester, _daily(DateTime.utc(9999, 11, 30, 9)));
      await _ending(tester);
      expect(find.text('Dec 31, 9999'), findsOneWidget);
      await _datePicker(tester);
      expect(tester.takeException(), isNull);
      await _confirm(tester);
      await _applyEnding(tester);
      expect(result.value!.rule!.until, DateTime.utc(9999, 12, 31));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview never proposes an occurrence after supported year 9999',
    (tester) async {
      final result = await _open(
        tester,
        RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          start: DateTime.utc(9999, 12, 31, 9),
          timeZoneId: 'UTC',
          weekdays: {DateTime.saturday},
        ),
      );
      expect(find.textContaining('No matching occurrence.'), findsOneWidget);
      expect(find.textContaining('10000'), findsNothing);
      expect(result.completed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'date selection preserves skipped device date and inclusive calendar semantics',
    (tester) async {
      final start = DateTime.utc(2011, 12, 29, 23, 30, 12, 345, 678);
      final result = await _open(
        tester,
        _daily(start, until: DateTime.utc(2011, 12, 29)),
      );
      await _ending(tester);
      await _datePicker(tester);
      await _select(tester, 'day', 29);
      expect(result.completed, isFalse);
      await _confirm(tester);
      expect(find.text('Dec 30, 2011'), findsOneWidget);
      await _applyEnding(tester);
      expect(result.value!.rule!.until, DateTime.utc(2011, 12, 30));
      expect(result.value!.rule!.start, start);
      expect(result.value!.countChanged, isTrue);
    },
  );

  testWidgets(
    'cancelling the date picker keeps the previous end and unchanged count flag',
    (tester) async {
      final until = DateTime.utc(2030, 2, 20);
      final result = await _open(
        tester,
        _daily(DateTime.utc(2030, 2, 10, 9), until: until),
      );
      await _ending(tester);
      await _datePicker(tester);
      await _select(tester, 'day', 24);
      await tester.tap(find.byKey(const ValueKey('civil-picker-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Feb 20, 2030'), findsOneWidget);
      await _applyEnding(tester);
      expect(result.value!.rule!.until, until);
      expect(result.value!.countChanged, isFalse);
    },
  );

  testWidgets(
    'an end before the start shows an error and cannot replace the valid end',
    (tester) async {
      final until = DateTime.utc(2030, 2, 20);
      final result = await _open(
        tester,
        _daily(DateTime.utc(2030, 2, 10, 9), until: until),
      );
      await _ending(tester);
      await _datePicker(tester);
      await _select(tester, 'day', 8);
      await _confirm(tester);
      await tester.ensureVisible(
        find.text('The end date cannot precede the start date.'),
      );
      expect(
        find.text('The end date cannot precede the start date.'),
        findsOneWidget,
      );
      expect(find.text('Feb 20, 2030'), findsOneWidget);
      expect(result.completed, isFalse);
      // Selecting a valid date after the rejection clears the validation error.
      await _datePicker(tester);
      await _select(tester, 'day', 21);
      await _confirm(tester);
      expect(
        find.text('The end date cannot precede the start date.'),
        findsNothing,
      );
      await _applyEnding(tester);
      expect(result.value!.rule!.until, DateTime.utc(2030, 2, 22));
    },
  );
}
