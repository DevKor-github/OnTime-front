import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/device_civil_day.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/home/bloc/weekly_schedules_bloc.dart';

ScheduleEntity appointment(
  String id,
  DateTime civil,
  String zone,
  int offset,
) => ScheduleEntity(
  id: id,
  place: const PlaceEntity(id: 'place', placeName: 'Place'),
  scheduleName: id,
  scheduleTime: civil,
  timeZoneId: zone,
  occurrenceOffsetSeconds: offset,
  moveTime: Duration.zero,
  scheduleSpareTime: Duration.zero,
  isChanged: false,
  isStarted: false,
  scheduleNote: '',
);

void main() {
  test(
    'device today contains an instant while calendar keeps original civil date',
    () {
      final now = DateTime.utc(2026, 9, 24, 23, 50);
      final seoul = appointment(
        'seoul',
        DateTime.utc(2026, 9, 25, 9),
        'Asia/Seoul',
        32400,
      );
      final state = WeeklySchedulesState(schedules: [seoul]);
      final appointmentDevice = DateTime.utc(2026, 9, 25).toLocal();
      final nowDevice = now.toLocal();
      final sameDay =
          appointmentDevice.year == nowDevice.year &&
          appointmentDevice.month == nowDevice.month &&
          appointmentDevice.day == nowDevice.day;
      expect(state.todayScheduleAt(now)?.id, sameDay ? 'seoul' : null);
      expect(state.dates.single, DateTime.utc(2026, 9, 25, 9));
      if (Platform.environment['TZ'] == 'America/New_York') {
        expect(nowDevice.day, 24);
        expect(appointmentDevice.day, 24);
        expect(state.todayScheduleAt(now)?.id, 'seoul');
      }
    },
  );

  test('today orders different civil values by their actual instants', () {
    final now = DateTime.utc(2026, 9, 25, 12);
    final later = appointment(
      'later',
      DateTime.utc(2026, 9, 25, 10),
      'America/New_York',
      -14400,
    );
    final earlier = appointment(
      'earlier',
      DateTime.utc(2026, 9, 25, 22),
      'Asia/Seoul',
      32400,
    );
    final state = WeeklySchedulesState(schedules: [later, earlier]);
    expect(state.todayScheduleAt(now)?.id, 'earlier');
  });

  test(
    'day boundary is inclusive at midnight and exclusive at next midnight',
    () {
      final day = DeviceCivilDay.at(DateTime.utc(2026, 9, 25, 12));
      expect(day.contains(day.startUtc), isTrue);
      expect(
        day.contains(day.endUtc.subtract(const Duration(microseconds: 1))),
        isTrue,
      );
      expect(day.contains(day.endUtc), isFalse);
    },
  );

  test('actual New York spring and autumn days span 23 and 25 hours', () {
    final spring = DeviceCivilDay.at(DateTime.utc(2026, 3, 8, 12));
    final autumn = DeviceCivilDay.at(DateTime.utc(2026, 11, 1, 12));
    if (Platform.environment['TZ'] == 'America/New_York') {
      expect(spring.startUtc, DateTime.utc(2026, 3, 8, 5));
      expect(spring.endUtc, DateTime.utc(2026, 3, 9, 4));
      expect(
        spring.endUtc.difference(spring.startUtc),
        const Duration(hours: 23),
      );
      expect(autumn.startUtc, DateTime.utc(2026, 11, 1, 4));
      expect(autumn.endUtc, DateTime.utc(2026, 11, 2, 5));
      expect(
        autumn.endUtc.difference(autumn.startUtc),
        const Duration(hours: 25),
      );
    } else {
      expect(spring.contains(DateTime.utc(2026, 3, 8, 12)), isTrue);
      expect(autumn.contains(DateTime.utc(2026, 11, 1, 12)), isTrue);
    }
  });
}
