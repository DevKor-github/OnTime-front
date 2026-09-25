import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/nearest_schedule_query.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
export 'package:on_time_front/domain/entities/nearest_schedule_query.dart';

NearestScheduleQuery nearestQueryFixture(
  ScheduleWithPreparationEntity? schedule,
  NearestQueryKey key,
) {
  final now = DateTime.now().toUtc();
  final authority = NearestQueryAuthority(
    key: key,
    storeIncarnation: 'fixture',
    dataRevision: 0,
    ruleDataIdentity: 'fixture',
    evaluatedAtUtc: now,
    verifiedAtUtc: now,
  );
  if (schedule == null) return NearestQueryEmpty(authority: authority);
  final resolution =
      schedule.timeResolution ??
      ScheduleTimeResolver.resolve(schedule, nowUtc: now);
  return NearestQueryReady(
    value: NearestVerifiedSchedule(
      schedule: schedule,
      resolution: resolution,
      authority: authority,
    ),
  );
}
