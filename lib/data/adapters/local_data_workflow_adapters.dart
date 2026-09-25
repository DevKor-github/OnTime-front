import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/domain/ports/local_data_ports.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

@LazySingleton(as: BackupOperationsPort)
class LocalBackupAdapter implements BackupOperationsPort {
  LocalBackupAdapter(this._backup);
  final BackupService _backup;
  @override
  int get generation => _backup.generation;
  Future<T> _safe<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on LocalDataOperationBusy {
      throw const DataOperationException(DataOperationFailure.busy);
    } on LocalDataUnavailable {
      throw const DataOperationException(DataOperationFailure.unavailable);
    } on DataOperationException {
      rethrow;
    } on FormatException {
      throw const DataOperationException(DataOperationFailure.invalidBackup);
    } catch (_) {
      throw const DataOperationException(DataOperationFailure.failed);
    }
  }

  @override
  Future<BackupFreshnessStatus> freshness() => _safe(_backup.getFreshness);
  @override
  Future<BackupExportResult> export(String password) =>
      _safe(() => _backup.exportToUserSelectedFile(password));
  @override
  Future<BackupRestoreInput?> preview(String password) =>
      _safe(() => _backup.selectAndPreviewRestore(password));
  @override
  Future<int> apply(BackupRestoreInput input) => _safe(
    () => _backup.applyRestoreWithReceipt(input as BackupRestoreCandidate),
  );
}

@LazySingleton(as: RestoreDeliveryPort)
class LocalRestoreDeliveryAdapter implements RestoreDeliveryPort {
  LocalRestoreDeliveryAdapter(this._reconcile);
  final ReconcileAlarmsUseCase _reconcile;
  @override
  Future<bool> reconcile() async {
    final result = await _reconcile();
    return (result.status == AlarmReconciliationStatus.armed ||
            result.status == AlarmReconciliationStatus.disabled) &&
        result.failures.isEmpty;
  }
}

@LazySingleton(as: LocalResetPort)
class LocalResetAdapter implements LocalResetPort {
  LocalResetAdapter(this._service);
  final LocalDataResetService _service;
  @override
  Future<LocalResetResult> reset() => _service.reset();
}

/// The same domain workflow can be used before DI without opening AppDatabase.
class RecoveryResetAdapter implements LocalResetPort {
  RecoveryResetAdapter(this._operation);
  final Future<LocalResetResult> Function() _operation;
  @override
  Future<LocalResetResult> reset() => _operation();
}
