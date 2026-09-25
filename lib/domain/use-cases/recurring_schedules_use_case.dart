import 'package:on_time_front/domain/use-cases/delete_schedule_use_case.dart';
import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
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
  RecurringSchedulesUseCase(
    this._recurring,
    this._schedules,
    ScheduleMutationAlarmEffectsCoordinator alarms,
    this.deletions,
  );
  final DeleteScheduleUseCase deletions;
  final RecurringScheduleRepository _recurring;
  final ScheduleRepository _schedules;

  Future<RecurringSegment> getSegment(String id) => _recurring.getSegment(id);

  Future<List<RecurringScheduleSummary>> list() async {
    final now = DateTime.now();
    final occurrences = await _schedules.getSchedulesByDate(
      now.subtract(const Duration(days: 2)),
      null,
    );
    final instants = {
      for (final value in occurrences)
        value.id: ScheduleTimeResolver.resolve(value, nowUtc: now).instantUtc,
    };
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
                    (instants[s.id]?.isAfter(now.toUtc()) ?? false),
              )
              .toList()
            ..sort((a, b) => instants[a.id]!.compareTo(instants[b.id]!));
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

  Future<ScheduleDeletionResult> delete(
    ScheduleEntity occurrence,
    RecurringEditScope scope,
  ) async {
    final intent = await deletions.prepare(occurrence.id, scope: scope);
    if (intent.snapshot.schedule != occurrence) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
    }
    return deletions.confirm(intent);
  }
}
