import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/repositories/recurring_schedule_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

class RecurringScheduleSummary {
  const RecurringScheduleSummary(this.segment, this.next);
  final RecurringSegment segment;
  final ScheduleEntity? next;
}

@Injectable()
class RecurringSchedulesUseCase {
  RecurringSchedulesUseCase(this._recurring, this._schedules, this._alarms);
  final RecurringScheduleRepository _recurring;
  final ScheduleRepository _schedules;
  final ScheduleMutationAlarmEffectsCoordinator _alarms;

  Future<RecurringSegment> getSegment(String id) => _recurring.getSegment(id);

  Future<List<RecurringScheduleSummary>> list() async {
    final now = DateTime.now();
    final occurrences = await _schedules.getSchedulesByDate(
      now.subtract(const Duration(days: 2)),
      null,
    );
    final segments = await _recurring.getSegments();
    final result = <RecurringScheduleSummary>[];
    for (final series in segments.map((s) => s.seriesId).toSet()) {
      final own = segments.where((s) => s.seriesId == series).toList()
        ..sort(
          (a, b) => a.createdAt == b.createdAt
              ? a.id.compareTo(b.id)
              : a.createdAt.compareTo(b.createdAt),
        );
      final ids = own.map((s) => s.id).toSet();
      final future =
          occurrences
              .where(
                (s) =>
                    ids.contains(s.recurringSegmentId) &&
                    !s.isStarted &&
                    !s.preparationFrozen &&
                    s.doneStatus == ScheduleDoneStatus.notEnded &&
                    s.occurrenceInstantUtc.isAfter(now.toUtc()),
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.occurrenceInstantUtc.compareTo(b.occurrenceInstantUtc),
            );
      result.add(
        RecurringScheduleSummary(
          own.last,
          future.isEmpty ? null : future.first,
        ),
      );
    }
    return result;
  }

  Future<RecurrenceReview?> review(ScheduleFormSubmission value) async {
    final rule = value.recurrenceRule;
    if (rule == null) return null;
    if (value.originalSchedule?.isRecurring ?? false) {
      if (value.recurringScope != RecurringEditScope.following) return null;
      return _recurring.reviewFollowing(
        value.originalSchedule!,
        value.schedule,
        value.preparation,
        rule,
        countChanged: value.recurrenceCountChanged,
      );
    }
    return _recurring.review(value.schedule, value.preparation, rule);
  }

  Future<void> delete(
    ScheduleEntity occurrence,
    RecurringEditScope scope,
  ) async {
    await _recurring.delete(occurrence, scope);
    await _alarms(
      operation: ScheduleMutationAlarmOperation.deleted,
      scheduleId: occurrence.id,
    );
  }
}
