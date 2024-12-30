import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/data/repositories/riverpod.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_schedules_for_month_use_case.g.dart';

@riverpod
Stream<List<ScheduleEntity>> getSchedulesForMonthUseCase(
    Ref ref, DateTime date) async* {
  final startOfMonth = DateTime(date.year, date.month, 1);
  final endOfMonth = DateTime(date.year, date.month + 1, 0);
  final scheduleRepository = ref.watch(scheduleRepositoryProvider);

  await scheduleRepository.getSchedulesByDate(startOfMonth, endOfMonth);

  await for (final schedules in scheduleRepository.scheduleStream) {
    yield schedules
        .where((schedule) =>
            schedule.scheduleTime.compareTo(startOfMonth) >= 0 &&
            schedule.scheduleTime.isBefore(endOfMonth))
        .toList();
  }
}
