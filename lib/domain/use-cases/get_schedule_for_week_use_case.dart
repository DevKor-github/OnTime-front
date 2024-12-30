import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/data/repositories/riverpod.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_schedule_for_week_use_case.g.dart';

@riverpod
Stream<List<ScheduleEntity>> getScheduleForWeekUseCase(
    Ref ref, DateTime date) async* {
  final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
  final endOfWeek = startOfWeek.add(Duration(days: 6));
  final scheduleRepository = ref.watch(scheduleRepositoryProvider);

  await scheduleRepository.getSchedulesByDate(startOfWeek, endOfWeek);

  await for (final schedules in scheduleRepository.scheduleStream) {
    yield schedules
        .where((schedule) =>
            schedule.scheduleTime.compareTo(startOfWeek) >= 0 &&
            schedule.scheduleTime.isBefore(endOfWeek))
        .toList();
  }
}
