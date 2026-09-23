import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';

enum RecurringEditScope { occurrence, following }

class RecurringSegment {
  const RecurringSegment({
    required this.id,
    required this.seriesId,
    required this.rule,
    required this.schedule,
    required this.preparation,
    required this.preparationId,
    required this.fromSlot,
    this.beforeSlot,
    required this.createdAt,
    this.preparationNotBefore,
  });
  final String id;
  final String seriesId;
  final RecurrenceRule rule;
  final ScheduleEntity schedule;
  final PreparationEntity preparation;
  final String preparationId;
  final DateTime fromSlot;
  final DateTime? beforeSlot;
  final DateTime createdAt;
  final DateTime? preparationNotBefore;
  Duration get leadTime =>
      preparation.totalDuration +
      schedule.moveTime +
      (schedule.scheduleSpareTime ?? Duration.zero);
  bool includes(RecurrenceSlot slot) =>
      !slot.civilTime.isBefore(fromSlot) &&
      (beforeSlot == null || slot.civilTime.isBefore(beforeSlot!));
}

class RecurrenceConflict {
  const RecurrenceConflict({
    required this.slot,
    required this.other,
    this.otherSlotKey,
  });
  final RecurrenceSlot slot;
  final ScheduleEntity other;
  final String? otherSlotKey;
}

class RecurrencePreviewOccurrence {
  const RecurrencePreviewOccurrence(this.schedule, this.preparationStartUtc);
  final ScheduleEntity schedule;
  final DateTime preparationStartUtc;
}

class RecurrenceReview {
  const RecurrenceReview({
    required this.slots,
    required this.skipped,
    this.conflicts = const [],
    this.detached = const [],
    this.persistentConflict = false,
    this.occurrences = const {},
    this.totalOccurrences,
  });
  final List<RecurrenceSlot> slots;
  final List<RecurrenceSkip> skipped;
  final List<RecurrenceConflict> conflicts;
  final List<ScheduleEntity> detached;
  final bool persistentConflict;
  final Map<String, RecurrencePreviewOccurrence> occurrences;

  /// Finite remaining occurrences, before exclusions chosen in this review.
  final int? totalOccurrences;
}

class RecurrenceNeedsReview implements Exception {
  const RecurrenceNeedsReview(this.review);
  final RecurrenceReview review;
  @override
  String toString() => review.persistentConflict
      ? '반복 시간이나 요일이 계속 겹쳐요. 반복 설정을 수정해 주세요.'
      : '겹치는 회차를 확인하고 제외할 일정을 선택해 주세요.';
}

class RecurrenceValidationException implements Exception {
  const RecurrenceValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}
