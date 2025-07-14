import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarTheme extends ThemeExtension<CalendarTheme> {
  final HeaderStyle headerStyle;
  final CalendarStyle calendarStyle;
  final DaysOfWeekStyle daysOfWeekStyle;
  final BoxDecoration? todayDecoration;

  const CalendarTheme({
    required this.headerStyle,
    required this.calendarStyle,
    required this.daysOfWeekStyle,
    this.todayDecoration,
  });

  @override
  ThemeExtension<CalendarTheme> copyWith({
    HeaderStyle? headerStyle,
    CalendarStyle? calendarStyle,
    DaysOfWeekStyle? daysOfWeekStyle,
    BoxDecoration? todayDecoration,
  }) {
    return CalendarTheme(
      headerStyle: headerStyle ?? this.headerStyle,
      calendarStyle: calendarStyle ?? this.calendarStyle,
      daysOfWeekStyle: daysOfWeekStyle ?? this.daysOfWeekStyle,
      todayDecoration: todayDecoration ?? this.todayDecoration,
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
      todayDecoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
    );
  }

  static CalendarTheme fromTheme(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return CalendarTheme.from(colorScheme, textTheme);
  }
}
