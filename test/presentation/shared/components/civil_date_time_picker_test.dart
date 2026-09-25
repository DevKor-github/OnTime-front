import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/civil_date_time_picker.dart';

class _Result {
  bool completed = false;
  DateTime? value;
}

Future<_Result> _open(
  WidgetTester tester, {
  required DateTime initial,
  required bool dateOnly,
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result.value = await showCivilDateTimePicker(
                context: context,
                initialCivil: initial,
                dateOnly: dateOnly,
                title: 'Schedule wall time',
              );
              result.completed = true;
            },
            child: const Text('Open picker'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open picker'));
  await tester.pumpAndSettle();
  expect(result.completed, isFalse);
  return result;
}

Future<void> _select(WidgetTester tester, String wheel, int index) async {
  // Use the actual scrolling widget and notification path, never call a
  // selection callback or a private state method to manufacture a result.
  final picker = tester.widget<CupertinoPicker>(
    find.byKey(ValueKey('civil-picker-$wheel')),
  );
  picker.scrollController!.jumpToItem(index);
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('civil-picker-confirm'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

String _preview(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('civil-picker-preview')))
    .data!;

void main() {
  testWidgets(
    'choosing 02:30 on the New York gap date preserves civil fields',
    (tester) async {
      if (Platform.environment['TZ'] == 'America/New_York') {
        expect(
          DateTime(2026, 3, 8, 2, 30).hour,
          3,
          reason: 'This process must exercise the real device DST gap',
        );
      }
      final result = await _open(
        tester,
        initial: DateTime.utc(2026, 3, 8, 1, 30, 4, 123, 456),
        dateOnly: false,
      );
      final hour = find.byKey(const ValueKey('civil-picker-hour'));
      final picker = tester.widget<CupertinoPicker>(hour);
      final gesture = await tester.startGesture(tester.getCenter(hour));
      await gesture.moveBy(Offset(0, -picker.itemExtent));
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_preview(tester), contains('02:30:04'));
      expect(
        result.completed,
        isFalse,
        reason: 'Scrolling cannot commit a draft',
      );
      await _confirm(tester);
      expect(result.completed, isTrue);
      expect(result.value, DateTime.utc(2026, 3, 8, 2, 30, 4, 123, 456));
      expect(result.value!.isUtc, isTrue);
    },
  );

  testWidgets('choosing the date skipped by Apia preserves December 30', (
    tester,
  ) async {
    if (Platform.environment['TZ'] == 'Pacific/Apia') {
      expect(
        DateTime(2011, 12, 30, 12).day,
        isNot(30),
        reason: 'This process must exercise the real skipped device date',
      );
    }
    final result = await _open(
      tester,
      initial: DateTime.utc(2011, 12, 29, 12, 34, 56, 789, 123),
      dateOnly: true,
    );
    await _select(tester, 'day', 29);
    expect(_preview(tester), contains('12/30/2011'));
    expect(result.completed, isFalse);
    await _confirm(tester);
    expect(result.value, DateTime.utc(2011, 12, 30, 12, 34, 56, 789, 123));
  });

  testWidgets(
    'shortening a leap year shows February 28 before explicit confirmation',
    (tester) async {
      final result = await _open(
        tester,
        initial: DateTime.utc(2024, 2, 29, 8, 9, 10, 111, 222),
        dateOnly: true,
      );
      await _select(tester, 'year', 2025 - 1);
      expect(_preview(tester), contains('2/28/2025'));
      final days = tester.widget<CupertinoPicker>(
        find.byKey(const ValueKey('civil-picker-day')),
      );
      expect(days.scrollController!.selectedItem, 27);
      expect(result.completed, isFalse);
      await _confirm(tester);
      expect(result.value, DateTime.utc(2025, 2, 28, 8, 9, 10, 111, 222));
    },
  );

  testWidgets(
    'month shortening and expanding keep the visible selected day consistent',
    (tester) async {
      final result = await _open(
        tester,
        initial: DateTime.utc(2024, 1, 31, 23, 59, 58, 777, 888),
        dateOnly: true,
      );
      await _select(tester, 'month', 1);
      expect(_preview(tester), contains('2/29/2024'));
      await _select(tester, 'month', 2);
      expect(_preview(tester), contains('3/29/2024'));
      await _select(tester, 'day', 30);
      expect(_preview(tester), contains('3/31/2024'));
      await _confirm(tester);
      expect(result.value, DateTime.utc(2024, 3, 31, 23, 59, 58, 777, 888));
    },
  );

  testWidgets('cancel discards the changed draft', (tester) async {
    final initial = DateTime.utc(2026, 9, 25, 9);
    final result = await _open(tester, initial: initial, dateOnly: false);
    await _select(tester, 'minute', 42);
    expect(_preview(tester), contains('09:42:00'));
    expect(result.completed, isFalse);
    await tester.tap(find.byKey(const ValueKey('civil-picker-cancel')));
    await tester.pumpAndSettle();
    expect(result.completed, isTrue);
    expect(result.value, isNull);
    expect(initial, DateTime.utc(2026, 9, 25, 9));
  });

  testWidgets('system back dismisses a changed draft without a selection', (
    tester,
  ) async {
    final result = await _open(
      tester,
      initial: DateTime.utc(2026, 9, 25, 9),
      dateOnly: true,
    );
    await _select(tester, 'month', 11);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result.completed, isTrue);
    expect(result.value, isNull);
  });

  for (final year in [1, 9999]) {
    testWidgets(
      'year $year remains selectable without overflowing the supported range',
      (tester) async {
        final result = await _open(
          tester,
          initial: DateTime.utc(
            year == 1 ? 2 : 9998,
            12,
            31,
            23,
            59,
            59,
            999,
            999,
          ),
          dateOnly: true,
        );
        await _select(tester, 'year', year - 1);
        await _confirm(tester);
        expect(result.value, DateTime.utc(year, 12, 31, 23, 59, 59, 999, 999));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final locale in [const Locale('en'), const Locale('ko')]) {
    for (final dateOnly in [true, false]) {
      testWidgets(
        '${locale.languageCode} ${dateOnly ? 'date' : 'time'} picker works at large text on a small screen',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 568));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          try {
            final initial = DateTime.utc(9999, 12, 31, 23, 59, 59, 123, 456);
            final result = await _open(
              tester,
              initial: initial,
              dateOnly: dateOnly,
              locale: locale,
              scale: 2.5,
            );
            final label = dateOnly
                ? (locale.languageCode == 'ko' ? '년' : 'Year')
                : (locale.languageCode == 'ko' ? '시' : 'Hour');
            expect(find.bySemanticsLabel(RegExp(label)), findsWidgets);
            expect(tester.takeException(), isNull);
            await _confirm(tester);
            expect(result.value, initial);
            expect(tester.takeException(), isNull);
          } finally {
            // Flutter verifies handles before package:test tearDown callbacks.
            semantics.dispose();
          }
        },
      );
    }
  }
}
