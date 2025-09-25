import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'No Schedule',
  type: TodaysScheduleTile,
)
Widget todaysScheduleTileNoSchedule(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(16.0),
    child: TodaysScheduleTile(),
  );
}

@widgetbook.UseCase(
  name: 'With Schedule',
  type: TodaysScheduleTile,
)
Widget todaysScheduleTileWithSchedule(BuildContext context) {
  final scheduleName = context.knobs.string(
    label: 'Schedule Name',
    initialValue: '팀 미팅',
  );
  final placeName = context.knobs.string(
    label: 'Place Name',
    initialValue: '강남역 스타벅스',
  );
  final scheduleTime = context.knobs.dateTime(
    label: 'Schedule Time',
    initialValue: DateTime.now().add(const Duration(hours: 2)),
    start: DateTime(2020, 1, 1),
    end: DateTime(2030, 12, 31),
  );

  final schedule = ScheduleEntity(
    id: 'schedule_1',
    place: PlaceEntity(id: 'place_1', placeName: placeName),
    scheduleName: scheduleName,
    scheduleTime: scheduleTime,
    moveTime: const Duration(minutes: 25),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 15),
    scheduleNote: '',
    latenessTime: 0,
  );

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: TodaysScheduleTile(
      schedule: schedule,
      onTap: () {},
    ),
  );
}
