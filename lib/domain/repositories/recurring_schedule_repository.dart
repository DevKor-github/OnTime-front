import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';

abstract interface class RecurringScheduleRepository {
  Future<List<RecurringSegment>> getSegments();
  Future<RecurringSegment> getSegment(String id);
  Future<RecurrenceReview> review(
    ScheduleEntity schedule,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    String? replacingSeriesId,
  });
  Future<void> create(
    ScheduleEntity schedule,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    Set<String> excludedSlots = const {},
    String? reviewedFirstSlotKey,
  });
  Future<void> updateOccurrence(
    ScheduleEntity original,
    ScheduleEntity updated,
    PreparationEntity preparation, {
    required bool preparationChanged,
  });
  Future<RecurrenceReview> reviewFollowing(
    ScheduleEntity original,
    ScheduleEntity updated,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    bool countChanged = false,
  });
  Future<void> updateFollowing(
    ScheduleEntity original,
    ScheduleEntity updated,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    bool countChanged = false,
    Set<String> excludedSlots = const {},
    String? reviewedFirstSlotKey,
    bool confirmDetached = false,
  });
  Future<void> delete(ScheduleEntity occurrence, RecurringEditScope scope);
  Future<void> materialize(
    DateTime from,
    DateTime through, {
    int? perSeriesLimit,
  });
  Future<PreparationEntity> getPreparation(String definitionId);
  ScheduleEntity candidateFor(RecurringSegment segment, RecurrenceSlot slot);
  Future<ScheduleEntity> materializeCandidate(
    RecurringSegment segment,
    RecurrenceSlot slot,
  );
}
