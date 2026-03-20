import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

class TodayTileNavigationTarget {
  const TodayTileNavigationTarget(this.path, {this.extra});

  final String path;
  final Map<String, dynamic>? extra;
}

TodayTileNavigationTarget? resolveTodayTileNavigationTarget({
  required ScheduleStatus scheduleStatus,
  required bool hasSchedule,
}) {
  if (!hasSchedule) {
    return null;
  }

  switch (scheduleStatus) {
    case ScheduleStatus.upcoming:
      return const TodayTileNavigationTarget(
        '/scheduleStart',
        extra: {'promptVariant': 'earlyStart'},
      );
    case ScheduleStatus.ongoing:
    case ScheduleStatus.started:
      return const TodayTileNavigationTarget('/alarmScreen');
    case ScheduleStatus.initial:
    case ScheduleStatus.notExists:
      return null;
  }
}
