import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_for_month_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_view_model.g.dart';

@riverpod
class CalendarViewModel extends _$CalendarViewModel {
  @override
  Future<Map<DateTime, List<ScheduleEntity>>> build(DateTime date) async {
    final scheduleList =
        await ref.watch(getSchedulesForMonthUseCaseProvider(date).future);
    final scheduleMap = <DateTime, List<ScheduleEntity>>{};
    //sort scheduleList by scheduleTime
    scheduleList.sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
    //group scheduleList by scheduleTime
    //ignore scheduleTime's time part
    for (final schedule in scheduleList) {
      final scheduleTime = DateTime(
        schedule.scheduleTime.year,
        schedule.scheduleTime.month,
        schedule.scheduleTime.day,
      );
      if (scheduleMap.containsKey(scheduleTime)) {
        scheduleMap[scheduleTime]!.add(schedule);
      } else {
        scheduleMap[scheduleTime] = [schedule];
      }
    }
    return scheduleMap;
  }

  void getSchedulesForMonth(DateTime date) async {
    final scheduleList =
        await ref.watch(getSchedulesForMonthUseCaseProvider(date).future);
    //add shceduleList to previous this.state
    final scheduleMap = <DateTime, List<ScheduleEntity>>{};
    //sort scheduleList by scheduleTime
    scheduleList.sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));
    //group scheduleList by scheduleTime
    //ignore scheduleTime's time part
    for (final schedule in scheduleList) {
      final scheduleTime = DateTime(
        schedule.scheduleTime.year,
        schedule.scheduleTime.month,
        schedule.scheduleTime.day,
      );
      if (scheduleMap.containsKey(scheduleTime)) {
        scheduleMap[scheduleTime]!.add(schedule);
      } else {
        scheduleMap[scheduleTime] = [schedule];
      }
    }

    await future;

    state = AsyncData({
      ...state.maybeMap(orElse: () => {}, data: (data) => data.value),
      ...scheduleMap,
    });
  }
}
