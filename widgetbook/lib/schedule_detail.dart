import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_detail.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: ScheduleDetail,
)
Widget scheduleDetailUseCase(BuildContext context) {
  // Create mock data
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
    initialValue: DateTime(2024, 1, 15, 14, 30),
    start: DateTime(2020, 1, 1),
    end: DateTime(2030, 12, 31),
  );

  final moveTime = context.knobs.duration(
    label: 'Move Time',
    initialValue: const Duration(minutes: 25),
  );

  final spareTime = context.knobs.duration(
    label: 'Spare Time',
    initialValue: const Duration(minutes: 15),
  );

  // Create mock entities
  final place = PlaceEntity(
    id: 'place_1',
    placeName: placeName,
  );

  final schedule = ScheduleEntity(
    id: 'schedule_1',
    place: place,
    scheduleName: scheduleName,
    scheduleTime: scheduleTime,
    moveTime: moveTime,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: spareTime,
    scheduleNote: '준비물: 노트북, 자료',
    latenessTime: 0,
  );

  return Scaffold(
    backgroundColor: const Color(0xFFF5F5F5),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ScheduleDetail(
          schedule: schedule,
          onEdit: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit tapped')),
            );
          },
          onDeleted: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Delete tapped')),
            );
          },
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Multiple Items',
  type: ScheduleDetail,
)
Widget multipleScheduleDetailsUseCase(BuildContext context) {
  // Create multiple mock schedules
  final schedules = [
    ScheduleEntity(
      id: 'schedule_1',
      place: PlaceEntity(id: 'place_1', placeName: '강남역 스타벅스'),
      scheduleName: '팀 미팅',
      scheduleTime: DateTime(2024, 1, 15, 9, 0),
      moveTime: const Duration(minutes: 25),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 15),
      scheduleNote: '준비물: 노트북',
      latenessTime: 0,
    ),
    ScheduleEntity(
      id: 'schedule_2',
      place: PlaceEntity(id: 'place_2', placeName: '홍대 카페'),
      scheduleName: '친구와 점심',
      scheduleTime: DateTime(2024, 1, 15, 12, 30),
      moveTime: const Duration(minutes: 45),
      isChanged: true,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 10),
      scheduleNote: '맛집 예약 확인',
      latenessTime: 5,
    ),
    ScheduleEntity(
      id: 'schedule_3',
      place: PlaceEntity(id: 'place_3', placeName: '회사'),
      scheduleName: '중요한 프레젠테이션',
      scheduleTime: DateTime(2024, 1, 15, 15, 0),
      moveTime: const Duration(hours: 1, minutes: 20),
      isChanged: false,
      isStarted: true,
      scheduleSpareTime: const Duration(minutes: 30),
      scheduleNote: 'PPT 최종 확인 필요',
      latenessTime: 0,
    ),
  ];

  return Scaffold(
    backgroundColor: const Color(0xFFF5F5F5),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView.separated(
            itemCount: schedules.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return ScheduleDetail(
                schedule: schedules[index],
                onEdit: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Edit ${schedules[index].scheduleName}')),
                  );
                },
                onDeleted: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Delete ${schedules[index].scheduleName}')),
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}
