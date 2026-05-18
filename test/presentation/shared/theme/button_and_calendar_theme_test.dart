import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:on_time_front/presentation/shared/theme/button_styles.dart';
import 'package:on_time_front/presentation/shared/theme/calendar_theme.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  test('button styles resolve enabled and disabled visual contracts', () {
    final colorScheme = themeData.colorScheme;
    final textTheme = themeData.textTheme;

    final primary = AppButtonStyles.elevatedPrimary(colorScheme, textTheme);
    final secondary = AppButtonStyles.elevatedSecondary(colorScheme, textTheme);
    final text = AppButtonStyles.textPrimary(colorScheme, textTheme);

    expect(primary.backgroundColor!.resolve({}), colorScheme.primary);
    expect(
      primary.backgroundColor!.resolve({WidgetState.disabled}),
      colorScheme.surfaceDim,
    );
    expect(primary.foregroundColor!.resolve({}), colorScheme.onPrimary);

    expect(
      secondary.backgroundColor!.resolve({}),
      colorScheme.primaryContainer,
    );
    expect(
      secondary.backgroundColor!.resolve({WidgetState.disabled}),
      colorScheme.surfaceDim,
    );
    expect(
      secondary.foregroundColor!.resolve({}),
      colorScheme.onPrimaryContainer,
    );
    expect(
      secondary.foregroundColor!.resolve({WidgetState.disabled}),
      colorScheme.onSurface.withValues(alpha: 0.38),
    );

    expect(text.textStyle!.resolve({}), textTheme.titleLarge);
    expect(text.padding!.resolve({}), EdgeInsets.zero);
    expect(text.foregroundColor!.resolve({}), colorScheme.primary);
    expect(
      text.foregroundColor!.resolve({WidgetState.disabled}),
      colorScheme.outlineVariant.withValues(alpha: 0.38),
    );
  });

  test('calendar theme builds app calendar tokens and copies overrides', () {
    final colorScheme = themeData.colorScheme;
    final textTheme = themeData.textTheme;
    final calendarTheme = CalendarTheme.from(colorScheme, textTheme);
    const overrideDecoration = BoxDecoration(color: Colors.red);

    final copied =
        calendarTheme.copyWith(selectedDayDecoration: overrideDecoration)
            as CalendarTheme;

    expect(calendarTheme.headerStyle.formatButtonVisible, isFalse);
    expect(calendarTheme.headerStyle.titleCentered, isTrue);
    expect(calendarTheme.calendarStyle.outsideDaysVisible, isFalse);
    expect(
      calendarTheme.calendarStyle.markerDecoration,
      BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
    );
    expect(
      calendarTheme.daysOfWeekStyle.dowTextFormatter!.call(
        DateTime(2026),
        'en',
      ),
      'Thu',
    );
    expect(copied.selectedDayDecoration, overrideDecoration);
    expect(copied.todayDecoration, calendarTheme.todayDecoration);
    expect(
      calendarTheme.lerp(
        CalendarTheme.from(
          colorScheme.copyWith(primary: Colors.red),
          textTheme,
        ),
        0.25,
      ),
      calendarTheme,
    );
    expect(
      calendarTheme.lerp(
        CalendarTheme.from(
          colorScheme.copyWith(primary: Colors.red),
          textTheme,
        ),
        0.75,
      ),
      isA<CalendarTheme>(),
    );
  });

  testWidgets('calendar theme can be derived from build context', (
    tester,
  ) async {
    late CalendarTheme resolved;

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Builder(
          builder: (context) {
            resolved = CalendarTheme.fromTheme(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      resolved.headerStyle.titleTextStyle.color,
      themeData.textTheme.titleMedium!.color,
    );
    expect(
      resolved.headerStyle.titleTextStyle.fontSize,
      themeData.textTheme.titleMedium!.fontSize,
    );
  });
}
