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

  /// Fingerprint for validating whether cached timed-preparation is still valid.
  String get cacheFingerprint {
    final spare = scheduleSpareTime ?? Duration.zero;
    final buffer = StringBuffer()
      ..write(scheduleTime.millisecondsSinceEpoch)
      ..write('|')
      ..write(moveTime.inMilliseconds)
      ..write('|')
      ..write(spare.inMilliseconds)
      ..write('|');

    for (final step in preparation.preparationStepList) {
      buffer
        ..write(step.id)
        ..write(':')
        ..write(step.preparationName)
        ..write(':')
        ..write(step.preparationTime.inMilliseconds)
        ..write(':')
        ..write(step.nextPreparationId ?? '')
        ..write('|');
    }

    return buffer.toString();
  }

  /// Returns the time remaining before needing to leave at [now].
  Duration timeRemainingBeforeLeavingAt(DateTime now) {
    final spareTime = scheduleSpareTime ?? Duration.zero;
    final remaining = scheduleTime.difference(now) - moveTime - spareTime;
    return remaining;
  }

  /// Returns the time remaining before needing to leave
  Duration get timeRemainingBeforeLeaving {
    return timeRemainingBeforeLeavingAt(DateTime.now());
  }

  /// Returns whether the schedule is running late at [now].
  bool isLateAt(DateTime now) {
    return timeRemainingBeforeLeavingAt(now).isNegative;
  }

  /// Returns whether the schedule is running late
  bool get isLate {
    return isLateAt(DateTime.now());
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
