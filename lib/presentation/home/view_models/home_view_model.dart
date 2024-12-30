import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_for_week_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_view_model.g.dart';

@riverpod
class HomeViewModel extends _$HomeViewModel {
  @override
  Future<List<ScheduleEntity>> build(DateTime date) async {
    return await ref.watch(getSchedulesForWeekUseCaseProvider(date).future);
  }

  List<DateTime> getDatesOfSchedule(List<ScheduleEntity> schedules) {
    return schedules.map((schedule) => schedule.scheduleTime).toList();
  }
}
