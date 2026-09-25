part of 'schedule_bloc.dart';

class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

final class ScheduleSubscriptionRequested extends ScheduleEvent {
  const ScheduleSubscriptionRequested();

  @override
  List<Object?> get props => [];
}

final class ScheduleUpcomingReceived extends ScheduleEvent {
  final ScheduleWithPreparationEntity? upcomingSchedule;
  final int? generation;

  const ScheduleUpcomingReceived(
    ScheduleWithPreparationEntity? upcomingScheduleWithPreparation, {
    this.generation,
  }) : upcomingSchedule = upcomingScheduleWithPreparation;

  @override
  List<Object?> get props => [upcomingSchedule, generation];
}

final class ScheduleAlarmPromptRequested extends ScheduleEvent {
  final String scheduleId;
  final String? scheduleFingerprint;
  final bool startPreparation;

  const ScheduleAlarmPromptRequested({
    required this.scheduleId,
    this.scheduleFingerprint,
    this.startPreparation = false,
  });

  @override
  List<Object?> get props => [
    scheduleId,
    scheduleFingerprint,
    startPreparation,
  ];
}

final class ScheduleStarted extends ScheduleEvent {
  const ScheduleStarted() : _boundaryIntent = null;
  const ScheduleStarted._owned(this._boundaryIntent);
  final _BoundaryStartIntent? _boundaryIntent;

  @override
  List<Object?> get props => [];
}

final class SchedulePreparationStarted extends ScheduleEvent {
  const SchedulePreparationStarted({this.receipt, this.isCurrent});
  final Completer<PreparationStartReceipt?>? receipt;
  final bool Function()? isCurrent;

  @override
  List<Object?> get props => [];
}

final class ScheduleTick extends ScheduleEvent {
  final Duration elapsed;

  const ScheduleTick(this.elapsed);

  @override
  List<Object?> get props => [elapsed];
}

enum PreparationRefreshOrigin { periodic, resume, restore, manual }

final class SchedulePreparationTimeRefreshRequested extends ScheduleEvent {
  const SchedulePreparationTimeRefreshRequested({
    this.origin = PreparationRefreshOrigin.manual,
  });

  final PreparationRefreshOrigin origin;

  @override
  List<Object?> get props => [origin];
}

final class ScheduleStepSkipped extends ScheduleEvent {
  const ScheduleStepSkipped();
}

final class ScheduleFinished extends ScheduleEvent {
  final int latenessTime;

  const ScheduleFinished(this.latenessTime);

  @override
  List<Object?> get props => [latenessTime];
}

final class _NotificationPromptPresented extends ScheduleEvent {
  const _NotificationPromptPresented(this.schedule, this.owner, this.isCurrent);
  final ScheduleWithPreparationEntity schedule;
  final Object owner;
  final bool Function() isCurrent;
  @override
  List<Object?> get props => [schedule, owner];
}

final class SchedulePreparationRecoveryRequested extends ScheduleEvent {
  const SchedulePreparationRecoveryRequested();
}

// Internal subscription authority does not alter the public event contract.
final class _OwnedScheduleUpcomingReceived extends ScheduleUpcomingReceived {
  const _OwnedScheduleUpcomingReceived(
    super.upcomingScheduleWithPreparation,
    int generation,
    this.subscriptionRevision,
  ) : super(generation: generation);
  final int subscriptionRevision;

  @override
  List<Object?> get props => [...super.props, subscriptionRevision];
}

final class _OwnedScheduleUpcomingReadFailed extends ScheduleEvent {
  const _OwnedScheduleUpcomingReadFailed(
    this.generation,
    this.subscriptionRevision,
  );
  final int generation;
  final int subscriptionRevision;
  @override
  List<Object?> get props => [generation, subscriptionRevision];
}

final class ScheduleNearestQueryRetryRequested extends ScheduleEvent {
  const ScheduleNearestQueryRetryRequested(this.queryKey);
  final NearestQueryKey queryKey;
  @override
  List<Object?> get props => [queryKey];
}

final class ScheduleNearestQueryContinueRequested extends ScheduleEvent {
  const ScheduleNearestQueryContinueRequested(this.queryKey);
  final NearestQueryKey queryKey;
  @override
  List<Object?> get props => [queryKey];
}

final class ScheduleNearestQueryCancelRequested extends ScheduleEvent {
  const ScheduleNearestQueryCancelRequested(this.queryKey);
  final NearestQueryKey queryKey;
  @override
  List<Object?> get props => [queryKey];
}

final class _NearestQueryReceived extends ScheduleEvent {
  const _NearestQueryReceived(this.query, this.subscriptionRevision);
  final NearestScheduleQuery query;
  final int subscriptionRevision;
  @override
  List<Object?> get props => [query, subscriptionRevision];
}

final class _NearestProjectionInvalidated extends ScheduleEvent {
  const _NearestProjectionInvalidated({this.replaced = false});
  final bool replaced;
}

final class _NotificationPreparationOwnershipChanged extends ScheduleEvent {
  const _NotificationPreparationOwnershipChanged();
}

class _BoundaryStartIntent {
  const _BoundaryStartIntent(
    this.key,
    this.scheduleId,
    this.fingerprint,
    this.target,
    this.observedWall,
    this.observedMonotonic,
  );
  final NearestQueryKey key;
  final String scheduleId;
  final String fingerprint;
  final DateTime target;
  final DateTime observedWall;
  final Duration observedMonotonic;
}
