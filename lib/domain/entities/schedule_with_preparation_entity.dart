import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

class ScheduleWithPreparationEntity extends ScheduleEntity {
  final PreparationWithTimeEntity preparation;

  const ScheduleWithPreparationEntity({
    required super.id,
    required super.place,
    required super.scheduleName,
    required super.scheduleTime,
    required super.moveTime,
    required super.isChanged,
    required super.isStarted,
    required super.scheduleSpareTime,
    required super.scheduleNote,
    required this.preparation,
  });

  ///Returns the total duration of the schedule including the moving time and the preparation time.
  Duration get totalDuration =>
      moveTime +
      preparation.totalDuration +
      (scheduleSpareTime ?? Duration.zero);

  ///Returns the time when the preparation starts.
  DateTime get preparationStartTime => scheduleTime.subtract(totalDuration);

  /// Returns the time remaining before needing to leave
  Duration get timeRemainingBeforeLeaving {
    final now = DateTime.now();
    final spareTime = scheduleSpareTime ?? Duration.zero;
    final remaining = scheduleTime.difference(now) - moveTime - spareTime;
    return remaining;
  }

  /// Returns whether the schedule is running late
  bool get isLate {
    return timeRemainingBeforeLeaving.isNegative;
  }

  static ScheduleWithPreparationEntity fromScheduleAndPreparationEntity(
      ScheduleEntity schedule, PreparationWithTimeEntity preparation) {
    return ScheduleWithPreparationEntity(
      id: schedule.id,
      place: schedule.place,
      scheduleName: schedule.scheduleName,
      scheduleTime: schedule.scheduleTime,
      moveTime: schedule.moveTime,
      isChanged: schedule.isChanged,
      isStarted: schedule.isStarted,
      scheduleSpareTime: schedule.scheduleSpareTime,
      scheduleNote: schedule.scheduleNote,
      preparation: preparation,
    );
  }

  @override
  List<Object?> get props => [
        id,
        place,
        scheduleName,
        scheduleTime,
        moveTime,
        isChanged,
        isStarted,
        scheduleSpareTime,
        scheduleNote,
        preparation
      ];
}
