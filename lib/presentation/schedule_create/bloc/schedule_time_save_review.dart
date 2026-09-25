import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';

/// Ephemeral confirmation of an exact form projection, never a new writer.
final class ScheduleTimeSaveReview {
  const ScheduleTimeSaveReview({
    required this.original,
    required this.proposed,
    required this.resolution,
    required this.baseline,
    required this.reviewedAtUtc,
    required this.preparationStartUtc,
    required this.rulesIdentity,
    required this.formOwner,
    required this.draftRevision,
    required this.editing,
  });
  final ScheduleEntity? original;
  final ScheduleEntity proposed;
  final ScheduleTimeResolution resolution;
  final ScheduleEditBaseline? baseline;
  final DateTime reviewedAtUtc;
  final DateTime preparationStartUtc;
  final String rulesIdentity;
  final Object formOwner;
  final int draftRevision;
  final bool editing;
}
