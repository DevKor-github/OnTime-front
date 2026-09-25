import 'package:on_time_front/core/time/device_civil_day.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

enum HomeScheduleCardKind { none, today, next, active, prompt, stale }

final class HomeScheduleCardSelection {
  const HomeScheduleCardSelection(
    this.schedule, {
    this.kind = HomeScheduleCardKind.none,
    this.resolution,
  });
  final ScheduleWithPreparationEntity? schedule;
  final HomeScheduleCardKind kind;
  final ScheduleTimeResolution? resolution;
  bool get isActive => kind == HomeScheduleCardKind.active;
  bool get canOpenPreparation =>
      schedule != null &&
      kind != HomeScheduleCardKind.stale &&
      kind != HomeScheduleCardKind.none;

  factory HomeScheduleCardSelection.at(ScheduleState state, DateTime now) {
    final schedule = state.schedule;
    if (schedule != null &&
        schedule.doneStatus == ScheduleDoneStatus.notEnded &&
        schedule.isStarted &&
        schedule.startedAt != null &&
        schedule.preparationFrozen) {
      return HomeScheduleCardSelection(
        schedule,
        kind: HomeScheduleCardKind.active,
        resolution:
            schedule.timeResolution ??
            ScheduleTimeResolver.resolve(schedule, nowUtc: now),
      );
    }
    if (state.hasOwnedPreparationSurface) {
      if (schedule != null &&
          schedule.doneStatus == ScheduleDoneStatus.notEnded) {
        return HomeScheduleCardSelection(
          schedule,
          kind: HomeScheduleCardKind.prompt,
          resolution:
              schedule.timeResolution ??
              ScheduleTimeResolver.resolve(schedule, nowUtc: now),
        );
      }
      return const HomeScheduleCardSelection(null);
    }
    final fresh = state.freshNearest;
    final value = fresh ?? state.staleNearest;
    if (value == null ||
        value.schedule.doneStatus != ScheduleDoneStatus.notEnded ||
        value.schedule.retainedRecurringReference) {
      return const HomeScheduleCardSelection(null);
    }
    final instant = value.resolution.instantUtc;
    if (instant == null) return const HomeScheduleCardSelection(null);
    return HomeScheduleCardSelection(
      value.schedule,
      resolution: value.resolution,
      kind: fresh == null
          ? HomeScheduleCardKind.stale
          : DeviceCivilDay.at(now).contains(instant)
          ? HomeScheduleCardKind.today
          : HomeScheduleCardKind.next,
    );
  }
}
