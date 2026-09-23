import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

class ScheduleWithPreparationEntity extends ScheduleEntity {
  final PreparationWithTimeEntity preparation;

  const ScheduleWithPreparationEntity({
    required super.id,
    required super.place,
    required super.scheduleName,
    super.timeZoneId,
    super.occurrenceOffsetSeconds,
    required super.scheduleTime,
    required super.moveTime,
    required super.isChanged,
    required super.isStarted,
    required super.scheduleSpareTime,
    required super.scheduleNote,
    super.latenessTime,
    super.doneStatus,
    super.startedAt,
    super.finishedAt,
    super.preparationMode,
    super.preparationTemplateId,
    super.preparationTemplateName,
    super.preparationTemplateDeleted,
    super.preparationFrozen,
    super.scoreContributionRecorded,
    super.customPreparations,
    super.recurringSegmentId,
    super.recurringSlotKey,
    super.recurringOrdinal,
    super.recurringOverrides,
    super.preparationDefinitionId,

    required this.preparation,
  });

  ///Returns the total duration of the schedule including the moving time and the preparation time.
  Duration get totalDuration =>
      moveTime +
      preparation.totalDuration +
      (scheduleSpareTime ?? Duration.zero);

  ///Returns the time when the preparation starts.
  DateTime get preparationStartTime =>
      occurrenceInstantUtc.subtract(totalDuration);

  /// Fingerprint for validating whether cached timed-preparation is still valid.
  String get timingIdentity => _identity('timing', [
    occurrenceInstantUtc.toIso8601String(),
    timeZoneId,
    occurrenceOffsetSeconds,
    moveTime.inMilliseconds,
    (scheduleSpareTime ?? Duration.zero).inMilliseconds,
  ]);

  String get preparationShapeIdentity => _identity('shape', [
    for (final step in preparation.preparationStepList)
      [
        step.id,
        step.preparationName,
        step.preparationTime.inMilliseconds,
        step.nextPreparationId,
      ],
  ]);

  String get cacheFingerprint =>
      _identity('session', [timingIdentity, preparationShapeIdentity]);

  static String _identity(String domain, List<Object?> values) =>
      'v2:${sha256.convert(utf8.encode(jsonEncode(['ontime', 2, domain, values])))}';

  static bool isCurrentIdentity(String value) =>
      RegExp(r'^v2:[0-9a-f]{64}$').hasMatch(value);

  /// Read-only compatibility comparison. Never persist or log this value.
  String get legacyCacheFingerprint {
    final spare = scheduleSpareTime ?? Duration.zero;
    final buffer = StringBuffer()
      ..write(scheduleTime.toIso8601String())
      ..write('|')
      ..write(timeZoneId)
      ..write('|')
      ..write(occurrenceOffsetSeconds)
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
    final remaining =
        occurrenceInstantUtc.difference(now.toUtc()) - moveTime - spareTime;
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
    ScheduleEntity schedule,
    PreparationWithTimeEntity preparation,
  ) {
    return ScheduleWithPreparationEntity(
      id: schedule.id,
      place: schedule.place,
      scheduleName: schedule.scheduleName,
      timeZoneId: schedule.timeZoneId,
      occurrenceOffsetSeconds: schedule.occurrenceOffsetSeconds,
      scheduleTime: schedule.scheduleTime,
      moveTime: schedule.moveTime,
      isChanged: schedule.isChanged,
      isStarted: schedule.isStarted,
      scheduleSpareTime: schedule.scheduleSpareTime,
      scheduleNote: schedule.scheduleNote,
      latenessTime: schedule.latenessTime,
      doneStatus: schedule.doneStatus,
      startedAt: schedule.startedAt,
      finishedAt: schedule.finishedAt,
      preparationMode: schedule.preparationMode,
      preparationTemplateId: schedule.preparationTemplateId,
      preparationTemplateName: schedule.preparationTemplateName,
      preparationTemplateDeleted: schedule.preparationTemplateDeleted,
      preparationFrozen: schedule.preparationFrozen,
      scoreContributionRecorded: schedule.scoreContributionRecorded,
      customPreparations: schedule.customPreparations,
      recurringSegmentId: schedule.recurringSegmentId,
      recurringSlotKey: schedule.recurringSlotKey,
      recurringOrdinal: schedule.recurringOrdinal,
      recurringOverrides: schedule.recurringOverrides,
      preparationDefinitionId: schedule.preparationDefinitionId,

      preparation: preparation,
    );
  }

  @override
  List<Object?> get props => [
    id,
    place,
    scheduleName,
    timeZoneId,
    occurrenceOffsetSeconds,
    scheduleTime,
    moveTime,
    isChanged,
    isStarted,
    scheduleSpareTime,
    scheduleNote,
    doneStatus,
    startedAt,
    finishedAt,
    preparationMode,
    preparationTemplateId,
    preparationTemplateName,
    preparationTemplateDeleted,
    preparationFrozen,
    scoreContributionRecorded,
    recurringSegmentId,
    recurringSlotKey,
    recurringOrdinal,
    recurringOverrides,
    preparationDefinitionId,
    preparation,
  ];
}
