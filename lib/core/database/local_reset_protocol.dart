export 'package:on_time_front/domain/entities/local_reset_result.dart'
    show LocalResetResult;
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';

abstract interface class LocalResetActions {
  Future<bool> hasMarker();
  Future<void> writeMarker();
  Future<void> removeMarker();
  Future<void> perform(ResetStep step);
}

/// Optional receipt for full-app provider cleanup, never used by ordinary OFF.
abstract interface class ResetGlobalDeliveryCleanup {
  bool get allProvidersConfirmedEmpty;
}

/// Runs under AlarmOperationCoordinator's owner, including before DI startup.
/// All progress is recoverable without the encrypted database or its key.
final class LocalResetProtocol {
  LocalResetProtocol(this.journal, this.cleanup, this.actions, {this.onIntent});
  final AlarmOwnershipJournal journal;
  final AlarmRegistrationCleanup cleanup;
  final LocalResetActions actions;
  final void Function()? onIntent;

  Future<LocalResetResult> run({required bool begin}) async {
    AlarmJournalSnapshot? state;
    var intentRecorded = false;
    var verifiedSteps = <ResetStep>{};
    try {
      final marker = await actions.hasMarker();
      try {
        state = await journal.read();
      } on AlarmJournalCorrupt {
        state = await cleanup.reconstructOwnership();
        if (marker || begin) {
          // Only independent secure intent or this explicit confirmation can
          // authorize deletion. Never recover completed stages from bad JSON.
          state.reset = ResetPhase.pending;
          state.unknownOwnership = state.unknownOwnership || marker;
          onIntent?.call();
        }
        await journal.recoverCorrupt(state);
        state = await journal.read();
      }
      if (!begin && !marker && state.reset == ResetPhase.none) {
        state = await cleanup.resolveLegacyIntegrity(state);
      }
      intentRecorded = state.reset != ResetPhase.none;
      verifiedSteps = Set.of(state.completed);
      if (state.reset == ResetPhase.complete) {
        // A failed final unlink must never cause user data deletion again.
        if (marker) await actions.removeMarker();
        if (await actions.hasMarker()) throw const AlarmJournalUnavailable();
        await journal.removeCompleted();
        return LocalResetResult(
          intentRecorded: true,
          completed: Set.of(state.completed),
          isComplete: true,
          recoveryRequired: false,
        );
      }
      if (!begin && !marker && state.reset != ResetPhase.pending) {
        return const LocalResetResult(
          intentRecorded: false,
          completed: {},
          recoveryRequired: false,
        );
      }
      if (state.reset != ResetPhase.pending) {
        // Migrate remaining registry ownership before any destructive operation.
        await journal.remember(
          await cleanup.operations.loadRecords(cleanup.registry),
        );
        state = await journal.read();
        // Legacy reset cleared preferences even when provider cancellation
        // failed. A marker without the new pending journal has lost evidence;
        // an empty registry cannot prove that those registrations are gone.
        state.unknownOwnership = state.unknownOwnership || marker;
        state.reset = ResetPhase.pending;
        // An uncertain intent write must not reopen ordinary writers when the
        // caller's replacement gate exits. No user data is deleted yet.
        onIntent?.call();
        await journal.save(state);
        intentRecorded = true;
      } else {
        onIntent?.call();
      }
      await actions.writeMarker();
      if (!await actions.hasMarker()) throw const AlarmJournalUnavailable();

      // Failed cancellation is a recorded partial result, not a reason to keep
      // deleted user content forever. Unreturned calls still hold the owner.
      if (!state.completed.contains(ResetStep.deliveries)) {
        try {
          final report = await cleanup.cancelMatchingReport();
          await actions.perform(ResetStep.deliveries);
          if (report.failed == 0) {
            state = await journal.read();
            final fullCleanup = actions;
            final unknownResolved =
                fullCleanup is ResetGlobalDeliveryCleanup &&
                (fullCleanup as ResetGlobalDeliveryCleanup)
                    .allProvidersConfirmedEmpty;
            if (state.ownership.isEmpty &&
                (!state.unknownOwnership || unknownResolved)) {
              state.unknownOwnership = false;
              state.completed.add(ResetStep.deliveries);
              await journal.save(state);
              verifiedSteps = Set.of(state.completed);
            }
          }
        } catch (_) {
          /* Keep the durable pending stage and ownership. */
        }
      }
      for (final step in ResetStep.values.where(
        (s) => s != ResetStep.deliveries,
      )) {
        state = await journal.read();
        if (state.completed.contains(step)) continue;
        try {
          await actions.perform(step);
          state = await journal.read();
          state.completed.add(step);
          await journal.save(state);
          verifiedSteps = Set.of(state.completed);
        } catch (_) {
          /* Retry only unfinished stages on a later run. */
        }
      }
      state = await journal.read();
      verifiedSteps = Set.of(state.completed);
      if (state.completed.length == ResetStep.values.length &&
          state.ownership.isEmpty &&
          !state.unknownOwnership) {
        state.reset = ResetPhase.complete;
        await journal.save(state);
        await actions.removeMarker();
        if (await actions.hasMarker()) throw const AlarmJournalUnavailable();
        await journal.removeCompleted();
        return LocalResetResult(
          intentRecorded: true,
          completed: Set.of(state.completed),
          isComplete: true,
          recoveryRequired: false,
        );
      }
    } catch (_) {
      // A storage failure is not permission to remove data or invent completion.
    }
    return LocalResetResult(
      intentRecorded: intentRecorded,
      completed: verifiedSteps,
    );
  }
}
