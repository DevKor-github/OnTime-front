import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:on_time_front/presentation/home/screens/home_screen_tmp.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// Mock data helper functions
PlaceEntity _createMockPlace({
  String id = "mock-place-1",
  String name = "Gangnam Station",
}) {
  return PlaceEntity(
    id: id,
    placeName: name,
  );
}

ScheduleEntity _createMockSchedule({
  String id = "mock-schedule-1",
  String name = "Team Meeting",
  DateTime? scheduleTime,
  PlaceEntity? place,
  Duration moveTime = const Duration(minutes: 30),
  Duration spareTime = const Duration(minutes: 15),
  String note = "Important meeting with the team",
}) {
  return ScheduleEntity(
    id: id,
    place: place ?? _createMockPlace(),
    scheduleName: name,
    scheduleTime: scheduleTime ?? DateTime.now().add(const Duration(hours: 2)),
    moveTime: moveTime,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: spareTime,
    scheduleNote: note,
    latenessTime: 0,
  );
}

MonthlySchedulesState _createMockStateWithSchedules() {
  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);

  final mockSchedules = {
    todayKey: [
      _createMockSchedule(
        id: "schedule-1",
        name: "Morning Meeting",
        scheduleTime: DateTime(today.year, today.month, today.day, 9, 30),
        place: _createMockPlace(id: "place-1", name: "Conference Room A"),
      ),
      _createMockSchedule(
        id: "schedule-2",
        name: "Lunch with Client",
        scheduleTime: DateTime(today.year, today.month, today.day, 12, 30),
        place: _createMockPlace(id: "place-2", name: "Restaurant Downtown"),
      ),
    ],
    DateTime(today.year, today.month, today.day + 1): [
      _createMockSchedule(
        id: "schedule-3",
        name: "Project Review",
        scheduleTime: DateTime(today.year, today.month, today.day + 1, 14, 0),
        place: _createMockPlace(id: "place-3", name: "Office Building"),
      ),
    ],
    DateTime(today.year, today.month, today.day + 2): [
      _createMockSchedule(
        id: "schedule-4",
        name: "Doctor Appointment",
        scheduleTime: DateTime(today.year, today.month, today.day + 2, 10, 0),
        place: _createMockPlace(id: "place-4", name: "Seoul Hospital"),
      ),
      _createMockSchedule(
        id: "schedule-5",
        name: "Gym Session",
        scheduleTime: DateTime(today.year, today.month, today.day + 2, 18, 0),
        place: _createMockPlace(id: "place-5", name: "Fitness Center"),
      ),
    ],
  };

  return MonthlySchedulesState(
    status: MonthlySchedulesStatus.success,
    schedules: mockSchedules,
    startDate: DateTime(today.year, today.month, 1),
    endDate: DateTime(today.year, today.month + 1, 0),
  );
}

MonthlySchedulesState _createEmptyMockState() {
  final today = DateTime.now();
  return MonthlySchedulesState(
    status: MonthlySchedulesStatus.success,
    schedules: const {},
    startDate: DateTime(today.year, today.month, 1),
    endDate: DateTime(today.year, today.month + 1, 0),
  );
}

MonthlySchedulesState _createLoadingMockState() {
  return const MonthlySchedulesState(
    status: MonthlySchedulesStatus.loading,
    schedules: {},
  );
}

@widgetbook.UseCase(
  name: 'With Multiple Schedules',
  type: HomeScreenContent,
)
Widget homeScreenContentWithSchedulesUseCase(BuildContext context) {
  return Scaffold(
    body: HomeScreenContent(
      state: _createMockStateWithSchedules(),
      userScore: 85.0,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Empty State',
  type: HomeScreenContent,
)
Widget homeScreenContentEmptyUseCase(BuildContext context) {
  return Scaffold(
    body: HomeScreenContent(
      state: _createEmptyMockState(),
      userScore: 75.0,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Loading State',
  type: HomeScreenContent,
)
Widget homeScreenContentLoadingUseCase(BuildContext context) {
  return Scaffold(
    body: HomeScreenContent(
      state: _createLoadingMockState(),
      userScore: 90.0,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Today Only Schedule',
  type: HomeScreenContent,
)
Widget homeScreenContentTodayOnlyUseCase(BuildContext context) {
  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);

  final mockState = MonthlySchedulesState(
    status: MonthlySchedulesStatus.success,
    schedules: {
      todayKey: [
        _createMockSchedule(
          name: "Important Meeting",
          scheduleTime: DateTime(today.year, today.month, today.day, 15, 0),
          place: _createMockPlace(name: "Conference Room"),
        ),
      ],
    },
    startDate: DateTime(today.year, today.month, 1),
    endDate: DateTime(today.year, today.month + 1, 0),
  );

  return Scaffold(
    body: HomeScreenContent(
      state: mockState,
      userScore: 95.0,
    ),
  );
}
