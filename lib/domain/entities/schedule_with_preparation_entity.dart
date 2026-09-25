import 'schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

class ScheduleWithPreparationEntity extends ScheduleEntity {
  final PreparationWithTimeEntity preparation;

  /// Immutable interpretation for one read pass; not a database/start authority.
  final ScheduleTimeResolution? timeResolution;

  @override
  DateTime get occurrenceInstantUtc {
    final resolved = timeResolution;
    if (resolved == null) return super.occurrenceInstantUtc;
    final instant = resolved.instantUtc;
    if (instant == null) throw ScheduleTimeUnresolved(resolved.status);
    return instant;
  }

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
    super.requiresStartConfirmation,
    super.retainedRecurringReference,
    super.scoreContributionRecorded,
    super.customPreparations,
    super.recurringSegmentId,
    super.recurringSlotKey,
    super.recurringOrdinal,
    super.recurringOverrides,
    super.preparationDefinitionId,

    required this.preparation,
    this.timeResolution,
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
  String get timingIdentity {
    final instant = occurrenceInstantUtc;
    final canonicalOffset =
        occurrenceOffsetSeconds ??
        CivilDateTime.fromFields(
          scheduleTime,
        ).toUtcCarrier().difference(instant).inSeconds;
    return _identity('timing', [
      instant.toIso8601String(),
      timeZoneId,
      canonicalOffset,
      moveTime.inMilliseconds,
      (scheduleSpareTime ?? Duration.zero).inMilliseconds,
    ]);
  }

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
      // The old SQLite civil converter constructed a local DateTime and its
      // legacy fingerprint therefore serialized wall fields without a Z. Do
      // not construct a device-local value here: a foreign DST gap could
      // normalize those fields and accidentally validate a different run.
      ..write(CivilDateTime.fromFields(scheduleTime).toCivilIso8601String())
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
    PreparationWithTimeEntity preparation, {
    required ScheduleTimeResolution timeResolution,
  }) {
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
      requiresStartConfirmation: schedule.requiresStartConfirmation,
      retainedRecurringReference: schedule.retainedRecurringReference,
      scoreContributionRecorded: schedule.scoreContributionRecorded,
      customPreparations: schedule.customPreparations,
      recurringSegmentId: schedule.recurringSegmentId,
      recurringSlotKey: schedule.recurringSlotKey,
      recurringOrdinal: schedule.recurringOrdinal,
      recurringOverrides: schedule.recurringOverrides,
      preparationDefinitionId: schedule.preparationDefinitionId,

      preparation: preparation,
      timeResolution: timeResolution,
    );
  }

  @override
  List<Object?> get props => [
    id,
    place,
    scheduleName,
    timeZoneId,
    occurrenceOffsetSeconds,
    CivilDateTime.fromFields(scheduleTime),
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
    requiresStartConfirmation,
    retainedRecurringReference,
    scoreContributionRecorded,
    recurringSegmentId,
    recurringSlotKey,
    recurringOrdinal,
    recurringOverrides,
    preparationDefinitionId,
    preparation,
    timeResolution,
  ];
}
