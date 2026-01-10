import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

/// Result class containing both previous and next schedules relative to a selected time
class AdjacentSchedulesWithPreparationEntity {
  final ScheduleWithPreparationEntity? previousSchedule;
  final ScheduleWithPreparationEntity? nextSchedule;

  const AdjacentSchedulesWithPreparationEntity({
    this.previousSchedule,
    this.nextSchedule,
  });

  bool get hasPrevious => previousSchedule != null;
  bool get hasNext => nextSchedule != null;
  bool get isEmpty => !hasPrevious && !hasNext;
}

