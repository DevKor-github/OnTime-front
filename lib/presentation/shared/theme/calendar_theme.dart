import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarTheme extends ThemeExtension<CalendarTheme> {
  final HeaderStyle headerStyle;
  final CalendarStyle calendarStyle;
  final DaysOfWeekStyle daysOfWeekStyle;
  final BoxDecoration selectedDayDecoration;
  final BoxDecoration todayDecoration;

  final TextStyle selectedDayTextStyle;
  final TextStyle todayTextStyle;

  const CalendarTheme({
    required this.headerStyle,
    required this.calendarStyle,
    required this.daysOfWeekStyle,
    required this.selectedDayDecoration,
    required this.todayDecoration,
    required this.selectedDayTextStyle,
    required this.todayTextStyle,
  });

  @override
  ThemeExtension<CalendarTheme> copyWith({
    HeaderStyle? headerStyle,
    CalendarStyle? calendarStyle,
    DaysOfWeekStyle? daysOfWeekStyle,
    BoxDecoration? selectedDayDecoration,
    BoxDecoration? todayDecoration,
    TextStyle? selectedDayTextStyle,
    TextStyle? todayTextStyle,
  }) {
    return CalendarTheme(
      headerStyle: headerStyle ?? this.headerStyle,
      calendarStyle: calendarStyle ?? this.calendarStyle,
      daysOfWeekStyle: daysOfWeekStyle ?? this.daysOfWeekStyle,
      selectedDayDecoration:
          selectedDayDecoration ?? this.selectedDayDecoration,
      todayDecoration: todayDecoration ?? this.todayDecoration,
      selectedDayTextStyle: selectedDayTextStyle ?? this.selectedDayTextStyle,
      todayTextStyle: todayTextStyle ?? this.todayTextStyle,
    );
  }

  @override
  ThemeExtension<CalendarTheme> lerp(
      covariant ThemeExtension<CalendarTheme>? other, double t) {
    if (other is! CalendarTheme) {
      return this;
    }
    // A simple lerp for non-lerpable properties
    return t < 0.5 ? this : other;
  }

  static CalendarTheme from(ColorScheme colorScheme, TextTheme textTheme) {
    final dayTextBase = textTheme.bodySmall ?? textTheme.bodyLarge!;

    return CalendarTheme(
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronVisible: false,
        rightChevronVisible: false,
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: colorScheme.outlineVariant,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: colorScheme.outlineVariant,
        ),
        titleTextStyle: textTheme.titleMedium!,
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (date, locale) => DateFormat.E(locale).format(date),
        weekdayStyle: textTheme.bodyLarge!,
        weekendStyle: textTheme.bodyLarge!,
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: textTheme.bodyLarge!,
        defaultTextStyle: textTheme.bodyLarge!,
        markerDecoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
        markerMargin: const EdgeInsets.symmetric(horizontal: 1.0),
      ),
      selectedDayDecoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
      todayDecoration: BoxDecoration(
        color: colorScheme.outlineVariant,
        shape: BoxShape.circle,
      ),
      selectedDayTextStyle: dayTextBase.copyWith(color: colorScheme.onPrimary),
      todayTextStyle: dayTextBase.copyWith(color: colorScheme.onPrimary),
    );
  }

  static CalendarTheme fromTheme(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return CalendarTheme.from(colorScheme, textTheme);
  }
}
