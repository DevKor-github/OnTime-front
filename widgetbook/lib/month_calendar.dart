import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/home/components/month_calendar.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/presentation/calendar/bloc/monthly_schedules_bloc.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: MonthCalendar,
)
Widget monthCalendarUseCase(BuildContext context) {
  // Build a simple fake schedules map for demonstration
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final Map<DateTime, List<ScheduleEntity>> schedules = {
    today: <ScheduleEntity>[],
    DateTime(now.year, now.month, (now.day + 1)): <ScheduleEntity>[],
  };

  final MonthlySchedulesState state = MonthlySchedulesState(
    status: MonthlySchedulesStatus.success,
    schedules: schedules,
    startDate: DateTime(now.year, now.month, 1),
    endDate: DateTime(now.year, now.month + 1, 0),
  );

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MonthCalendar(
          monthlySchedulesState: state,
          dispatchBlocEvents: false,
        ),
      ],
    ),
  );
}
