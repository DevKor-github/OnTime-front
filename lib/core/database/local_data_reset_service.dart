import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/local_reset_actions.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';

@lazySingleton
class LocalDataResetService {
  LocalDataResetService(
    this._database,
    this._keyStore,
    this._cancelAllAlarms, {
    @ignoreParam LocalDataOperationGate? operationGate,
    @ignoreParam LocalResetActions? resetActions,
  }) : _operationGate = operationGate ?? LocalDataOperationGate.shared,
       _resetActions = resetActions;

  final AppDatabase _database;
  final InstallationKeyStore _keyStore;
  final CancelAllAlarmsUseCase _cancelAllAlarms;
  final LocalDataOperationGate _operationGate;
  final LocalResetActions? _resetActions;
  Future<LocalResetResult>? _running;
  LocalResetResult? _completed;
  bool _databaseClosed = false;

  /// Repeated taps share the actual operation. A UI timeout never releases it.
  Future<LocalResetResult> reset() {
    final completed = _completed;
    if (completed != null) return Future.value(completed);
    final current = _running;
    if (current != null) return current;
    final next = _operationGate.isInvalidated
        ? _reset()
        : _operationGate.run(_reset, replacesData: true);
    _running = next.then((result) {
      if (result.isComplete) _completed = result;
      return result;
    }).whenComplete(() => _running = null);
    return _running!;
  }

  Future<LocalResetResult> _reset() {
    _operationGate.invalidate();
    return _cancelAllAlarms.withCleanupOwner(
      (cleanup) => LocalResetProtocol(
        _cancelAllAlarms.operations.journal,
        cleanup,
        _resetActions ??
            DeviceLocalResetActions(
              keyStore: _keyStore,
              closeDatabase: () async {
                if (!_databaseClosed) {
                  await _database.close();
                  _databaseClosed = true;
                }
              },
            ),
      ).run(begin: true),
    );
  }
}
