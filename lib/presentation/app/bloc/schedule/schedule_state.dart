part of 'schedule_bloc.dart';

enum ScheduleStatus { initial, notExists, upcoming, ongoing, started }

class ScheduleState extends Equatable {
  const ScheduleState._({
    required this.status,
    this.schedule,
    this.isEarlyStarted = false,
    this.notificationPromptOwner,
    this.hasPendingStartRecovery = false,
    this.isRecoveringStart = false,
    this.nearestQuery = const NearestQueryIdle(),
    this.hasNotificationPreparationOwner = false,
    this.isResumedPreparation = false,
  });

  const ScheduleState.initial() : this._(status: ScheduleStatus.initial);

  const ScheduleState.notExists() : this._(status: ScheduleStatus.notExists);

  const ScheduleState.upcoming(
    ScheduleWithPreparationEntity schedule, {
    Object? notificationPromptOwner,
  }) : this._(
         status: ScheduleStatus.upcoming,
         schedule: schedule,
         notificationPromptOwner: notificationPromptOwner,
       );

  const ScheduleState.ongoing(ScheduleWithPreparationEntity schedule)
    : this._(status: ScheduleStatus.ongoing, schedule: schedule);

  const ScheduleState.started(
    ScheduleWithPreparationEntity schedule, {
    bool isEarlyStarted = false,
    bool isResumedPreparation = false,
  }) : this._(
         status: ScheduleStatus.started,
         schedule: schedule,
         isEarlyStarted: isEarlyStarted,
         isResumedPreparation: isResumedPreparation,
       );

  final ScheduleStatus status;
  final ScheduleWithPreparationEntity? schedule;
  final bool isEarlyStarted;
  final Object? notificationPromptOwner;
  final bool hasPendingStartRecovery;
  final bool isRecoveringStart;

  /// The last projection is retained; it is not fresh start authority.
  final NearestScheduleQuery nearestQuery;
  final bool hasNotificationPreparationOwner;
  bool get hasUpcomingReadFailure => nearestQuery is NearestQueryError;
  NearestVerifiedSchedule? get freshNearest => switch (nearestQuery) {
    NearestQueryReady(:final value) => value,
    _ => null,
  };
  NearestVerifiedSchedule? get staleNearest => nearestQuery.stale;
  bool get hasOwnedPreparationSurface =>
      notificationPromptOwner != null ||
      hasNotificationPreparationOwner ||
      (schedule != null &&
          schedule!.doneStatus == ScheduleDoneStatus.notEnded &&
          schedule!.isStarted &&
          schedule!.startedAt != null &&
          schedule!.preparationFrozen);

  /// A read restored an existing run; it is not a new-start navigation event.
  final bool isResumedPreparation;

  ScheduleState copyWith({
    ScheduleStatus? status,
    ScheduleWithPreparationEntity? schedule,
    bool? isEarlyStarted,
    bool? hasPendingStartRecovery,
    bool? isRecoveringStart,
    NearestScheduleQuery? nearestQuery,
    bool? hasNotificationPreparationOwner,
    bool? isResumedPreparation,
  }) {
    return ScheduleState._(
      status: status ?? this.status,
      schedule: schedule ?? this.schedule,
      isEarlyStarted: isEarlyStarted ?? this.isEarlyStarted,
      notificationPromptOwner: notificationPromptOwner,
      hasPendingStartRecovery:
          hasPendingStartRecovery ?? this.hasPendingStartRecovery,
      isRecoveringStart: isRecoveringStart ?? this.isRecoveringStart,
      nearestQuery: nearestQuery ?? this.nearestQuery,
      hasNotificationPreparationOwner:
          hasNotificationPreparationOwner ??
          this.hasNotificationPreparationOwner,
      isResumedPreparation: isResumedPreparation ?? this.isResumedPreparation,
    );
  }

  Duration? get durationUntilPreparationStart {
    return durationUntilPreparationStartAt(DateTime.now());
  }

  Duration? durationUntilPreparationStartAt(DateTime now) {
    if (schedule == null) return null;
    final target = schedule!.preparationStartTime;
    if (target.isBefore(now) || target.isAtSameMomentAs(now)) return null;
    return target.difference(now);
  }

  @override
  List<Object?> get props => [
    status,
    schedule,
    schedule?.preparation,
    isEarlyStarted,
    notificationPromptOwner,
    hasPendingStartRecovery,
    isRecoveringStart,
    nearestQuery,
    hasNotificationPreparationOwner,
    isResumedPreparation,
  ];
}
