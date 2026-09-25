import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/domain/entities/schedule_not_found.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_aggregate_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';

@Injectable()
class DeleteScheduleUseCase {
  DeleteScheduleUseCase(
    this._repository,
    AlarmRegistryRepository registry,
    AlarmSchedulerService scheduler,
    FallbackAlarmNotificationService fallback,
    this._sessions,
    this._reconcile, {
    @ignoreParam AlarmOperationCoordinator? operations,
  }) : _operations = operations ?? AlarmOperationCoordinator.shared,
       _registry = registry,
       _cleanup = AlarmRegistrationCleanup(
         registry,
         scheduler,
         fallback,
         operations ?? AlarmOperationCoordinator.shared,
       );

  final ScheduleAggregateRepository _repository;
  final AlarmRegistryRepository _registry;
  final SchedulePreparationSessionUseCase _sessions;
  final ReconcileAlarmsUseCase _reconcile;
  final AlarmOperationCoordinator _operations;
  final AlarmRegistrationCleanup _cleanup;
  final _pending = Expando<Future<ScheduleDeletionResult>>();
  final _committed = Expando<ScheduleDeletionCommit>();
  final _retries = Expando<Future<ScheduleDeletionResult>>();

  int get currentGeneration => _operations.generation;

  bool isCurrentGeneration(int generation) =>
      _operations.canSchedule && _operations.generation == generation;

  Future<ScheduleDeletionIntent> prepare(
    String id, {
    RecurringEditScope scope = RecurringEditScope.occurrence,
  }) async {
    final lease = _operations.capture();
    final intent = await _repository.readForDeletion(id, scope: scope);
    lease.check();
    await _sessions.assertDeletionAllowed(intent.snapshot, lease: lease);
    lease.check();
    return intent;
  }

  Future<ScheduleDeletionResult> confirm(
    ScheduleDeletionIntent intent, {
    void Function(ScheduleDeletionCommit)? onCommitted,
  }) {
    final flight = _pending[intent];
    if (flight != null) return flight;
    final previous = _committed[intent];
    final future = previous == null
        ? _confirm(intent, onCommitted)
        : retryCleanup(previous);
    _pending[intent] = future;
    future.then<void>(
      (_) => _pending[intent] = null,
      onError: (Object _, StackTrace __) => _pending[intent] = null,
    );
    return future;
  }

  Future<ScheduleDeletionResult> _confirm(
    ScheduleDeletionIntent intent,
    void Function(ScheduleDeletionCommit)? onCommitted,
  ) async {
    final lease = _operations.capture();
    if (lease.generation != intent.snapshot.baseline.generation) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
    }
    final result = await _operations.run(lease, () async {
      // Re-read every target before preserving delivery ownership. A concurrent
      // durable write is checked again by the transaction before it commits.
      for (final target in intent.targets) {
        ScheduleDeletionIntent current;
        try {
          current = await _repository.readForDeletion(target.id);
        } on ScheduleNotFound {
          if (target.id != intent.snapshot.schedule.id) {
            throw const ScheduleDeletionRejected(
              ScheduleDeletionFailure.conflict,
            );
          }
          final commit = await _repository.delete(intent);
          _committed[intent] = commit;
          lease.check();
          if (onCommitted != null) {
            try {
              onCommitted(commit);
            } catch (_) {
              /* Observer only. */
            }
          }
          return _finishCleanup(commit, lease);
        }
        lease.check();
        if (current.snapshot.baseline.store != intent.snapshot.baseline.store ||
            current.snapshot.baseline.incarnation != target.incarnation ||
            current.snapshot.baseline.version != target.version) {
          throw const ScheduleDeletionRejected(
            ScheduleDeletionFailure.conflict,
          );
        }
        await _sessions.assertDeletionAllowed(current.snapshot, lease: lease);
        lease.check();
      }
      final stored = await _operations.loadRecords(_registry);
      lease.check();
      final ids = intent.targets.map((target) => target.id).toSet();
      final targets = stored
          .where((record) => ids.contains(record.scheduleId))
          .map(AlarmOperationCoordinator.ownershipOnly)
          .toList();
      // This write verifies its read-back. Even an empty projection must establish
      // journal availability/unknown ownership before identifiers can disappear.
      final journal = await _operations.journal.read();
      lease.check();
      for (final record in targets) {
        journal.ownership.putIfAbsent(
          alarmOwnershipKey(record),
          () => AlarmOwnership(record, pending: false),
        );
      }
      await _operations.journal.save(journal);
      lease.check();
      final commit = await _repository.delete(intent);
      _committed[intent] = commit;
      lease.check();
      if (onCommitted != null) {
        try {
          onCommitted(commit);
        } catch (_) {
          // An observer cannot undo a committed deletion or skip OS cleanup.
        }
      }
      return _finishCleanup(commit, lease);
    });
    if (lease.isCurrent) requestAlarmReconciliation(_reconcile);
    return result;
  }

  Future<ScheduleDeletionResult> retryCleanup(ScheduleDeletionCommit commit) {
    final running = _retries[commit];
    if (running != null) return running;
    final future = _retryCleanup(commit);
    _retries[commit] = future;
    future.then<void>(
      (_) => _retries[commit] = null,
      onError: (Object _, StackTrace __) => _retries[commit] = null,
    );
    return future;
  }

  Future<ScheduleDeletionResult> _retryCleanup(
    ScheduleDeletionCommit commit,
  ) async {
    final lease = _operations.capture();
    if (lease.generation != commit.generation) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
    }
    final result = await _operations.run(
      lease,
      () => _finishCleanup(commit, lease),
    );
    if (lease.isCurrent) requestAlarmReconciliation(_reconcile);
    return result;
  }

  Future<ScheduleDeletionResult> _finishCleanup(
    ScheduleDeletionCommit commit,
    AlarmOperationLease lease,
  ) async {
    if (!await _repository.isDeletionCurrent(commit)) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
    }
    lease.check();
    var state = ScheduleDeletionCleanup.complete;
    for (final id in {...commit.removedIds, commit.scheduleId}) {
      try {
        await _sessions.clearDeletedStateUnderOwner(
          id,
          lease: lease,
          isCurrent: () => _repository.isDeletionCurrent(commit),
        );
        lease.check();
      } on AlarmOperationInvalidated {
        rethrow;
      } catch (_) {
        state = ScheduleDeletionCleanup.unconfirmed;
      }
      // A same-ID replacement must not inherit the old cleanup authority.
      if (!await _repository.isDeletionCurrent(commit)) {
        throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
      }
      lease.check();
      try {
        final report = await _cleanup.cancelMatchingReport(
          scheduleId: id,
          isCurrent: () => lease.isCurrent,
          isStillOwned: () => _repository.isDeletionCurrent(commit),
        );
        lease.check();
        if (!report.isComplete && state == ScheduleDeletionCleanup.complete) {
          state = report.unknownOwnership
              ? ScheduleDeletionCleanup.unconfirmed
              : ScheduleDeletionCleanup.pending;
        }
      } on AlarmOperationInvalidated {
        rethrow;
      } catch (_) {
        state = ScheduleDeletionCleanup.unconfirmed;
      }
    }
    return ScheduleDeletionResult(commit: commit, cleanup: state);
  }

  /// Compatibility entry for already-confirmed callers. It still uses the safe
  /// workflow and refuses to silently replace the caller's displayed snapshot.
  Future<void> call(ScheduleEntity schedule) async {
    final intent = await prepare(schedule.id);
    if (intent.snapshot.schedule != schedule) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
    }
    await confirm(intent);
  }
}
