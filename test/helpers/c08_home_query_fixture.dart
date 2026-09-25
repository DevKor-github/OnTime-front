import 'package:on_time_front/domain/entities/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

const homeQueryKey = NearestQueryKey(generation: 7, epoch: 2, revision: 5);
const homeQueryProgress = NearestQueryProgress(
  visitedCandidates: 1024,
  candidateBudget: 200000,
  provenSegments: 1,
  totalSegments: 3,
);

NearestQueryAuthority homeQueryAuthority() => NearestQueryAuthority(
  key: homeQueryKey,
  storeIncarnation: 'fixture-store',
  dataRevision: 11,
  ruleDataIdentity: 'fixture-rules',
  evaluatedAtUtc: DateTime.utc(2029),
  verifiedAtUtc: DateTime.utc(2029),
);

// These are explicit UI projections, not evidence that a query writer ran.
NearestVerifiedSchedule homeVerifiedValue(
  ScheduleWithPreparationEntity schedule, {
  DateTime? instantUtc,
}) {
  assert(
    instantUtc != null ||
        (schedule.timeZoneId == 'UTC' && schedule.occurrenceOffsetSeconds == 0),
  );
  return NearestVerifiedSchedule(
    schedule: schedule,
    resolution: ScheduleTimeResolution(
      status: ScheduleTimeResolutionStatus.resolved,
      instantUtc: instantUtc ?? schedule.scheduleTime.toUtc(),
    ),
    authority: homeQueryAuthority(),
  );
}

ScheduleState homeReadyState(ScheduleWithPreparationEntity schedule) =>
    ScheduleState.upcoming(schedule).copyWith(
      nearestQuery: NearestQueryReady(value: homeVerifiedValue(schedule)),
    );

ScheduleState homeEmptyState() => const ScheduleState.notExists().copyWith(
  nearestQuery: NearestQueryEmpty(authority: homeQueryAuthority()),
);
