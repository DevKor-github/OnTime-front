import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_for_month_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_view_model.g.dart';

@riverpod
class CalendarViewModel extends _$CalendarViewModel {
  @override
  Future<List<ScheduleEntity>> build(DateTime date) async {
    return await ref.watch(getSchedulesForMonthUseCaseProvider(date).future);
  }
}
