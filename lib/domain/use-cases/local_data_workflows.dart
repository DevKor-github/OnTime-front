import '../entities/backup_restore_selection.dart';
import '../ports/backup_time_review_port.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/domain/ports/local_data_ports.dart';

@lazySingleton
class BackupWorkflow {
  BackupWorkflow(this._backup, this._delivery);
  final BackupOperationsPort _backup;
  final RestoreDeliveryPort _delivery;
  final _pending = Expando<Future<BackupRestoreReceipt>>();
  final _completed = Expando<BackupRestoreReceipt>();
  final _inputs = Expando<WeakReference<BackupRestoreInput>>();
  final _retries = Expando<Future<BackupRestoreReceipt>>();
  int get generation => _backup.generation;

  Future<BackupFreshnessStatus> freshness() => _backup.freshness();
  Future<BackupExportResult> export(String password) =>
      _backup.export(password);
  Future<BackupRestoreInput?> preview(String password) =>
      _backup.preview(password);

  Future<BackupRestoreSelection?> selectForRestore(String password) {
    final port = _backup;
    return port is BackupTimeReviewPort
        ? (port as BackupTimeReviewPort).selectForRestore(password)
        : port.preview(password);
  }

  Future<BackupRestoreReceipt> restore(BackupRestoreInput input) {
    final running = _pending[input];
    if (running != null) return running;
    final completed = _completed[input];
    if (completed != null) return Future.value(completed);
    return _pending[input] ??= _restore(
      input,
    ).whenComplete(() => _pending[input] = null);
  }

  Future<BackupRestoreReceipt> _restore(BackupRestoreInput input) async {
    final startedGeneration = generation;
    final int committedGeneration;
    try {
      committedGeneration = await _backup.apply(input);
    } on BackupRestoreCommitUncertain catch (error) {
      final receipt = BackupRestoreReceipt.uncertain(
        generation: error.generation,
      );
      _completed[input] = receipt;
      return receipt;
    } on DataOperationException catch (error) {
      return BackupRestoreReceipt(
        disposition: BackupCommitDisposition.notCommitted,
        generation: error.generation ?? startedGeneration,
        failure: error.failure,
        followUpPending: error.followUpPending,
      );
    } catch (_) {
      return BackupRestoreReceipt(
        disposition: BackupCommitDisposition.notCommitted,
        generation: startedGeneration,
        failure: DataOperationFailure.failed,
      );
    }

    // Record commit before waiting for external work. A thrown delivery result
    // can never cause the caller to replace durable data again.
    final pending = BackupRestoreReceipt(
      disposition: BackupCommitDisposition.committed,
      generation: committedGeneration,
      followUpPending: true,
    );
    _completed[input] = pending;
    _inputs[pending] = WeakReference(input);
    final result = await _followUp(pending);
    _completed[input] = result;
    _inputs[result] = WeakReference(input);
    return result;
  }

  Future<BackupRestoreReceipt> retryFollowUp(BackupRestoreReceipt receipt) {
    if (!receipt.followUpPending ||
        receipt.disposition == BackupCommitDisposition.undetermined) {
      return Future.value(receipt);
    }
    return _retries[receipt] ??= _followUp(
      receipt,
    ).whenComplete(() => _retries[receipt] = null);
  }

  Future<BackupRestoreReceipt> _followUp(BackupRestoreReceipt receipt) async {
    if (receipt.disposition == BackupCommitDisposition.undetermined) {
      return receipt;
    }
    if (receipt.generation != generation) {
      return BackupRestoreReceipt(
        disposition: receipt.disposition,
        generation: receipt.generation,
        followUpPending: true,
        failure: DataOperationFailure.stalePreview,
      );
    }
    var complete = false;
    try {
      complete = await _delivery.reconcile();
    } catch (_) {
      /* Safe partial receipt. */
    }
    final result = BackupRestoreReceipt(
      disposition: receipt.disposition,
      generation: receipt.generation,
      followUpPending: !complete || receipt.generation != generation,
    );
    final input = _inputs[receipt]?.target;
    if (input != null) {
      _completed[input] = result;
      _inputs[result] = WeakReference(input);
    }
    return result;
  }
}

@lazySingleton
class LocalResetWorkflow {
  LocalResetWorkflow(this._reset);
  final LocalResetPort _reset;
  Future<LocalResetResult> call() => _reset.reset();
}
