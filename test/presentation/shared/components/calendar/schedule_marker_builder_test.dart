import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/components/calendar/schedule_marker_builder.dart';

void main() {
  test('hides schedule marker when the day is selected', () {
    final marker = selectedDayScheduleMarkerBuilder(
      selectedDay: DateTime(2026, 5, 11),
      day: DateTime(2026, 5, 11, 9),
      events: const [Object()],
    );

    expect(marker, isA<SizedBox>());
  });

  test('uses the default marker when a scheduled day is not selected', () {
    final marker = selectedDayScheduleMarkerBuilder(
      selectedDay: DateTime(2026, 5, 11),
      day: DateTime(2026, 5, 12),
      events: const [Object()],
    );

    expect(marker, isNull);
  });

  test('uses the default empty-day behavior when there are no events', () {
    final marker = selectedDayScheduleMarkerBuilder<Object>(
      selectedDay: DateTime(2026, 5, 11),
      day: DateTime(2026, 5, 11),
      events: const [],
    );

    expect(marker, isNull);
  });
}
