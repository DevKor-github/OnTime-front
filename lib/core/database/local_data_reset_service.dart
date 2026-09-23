import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_files.dart';
import 'package:on_time_front/core/database/local_data_lifecycle.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class LocalDataResetService {
  LocalDataResetService(
    this._database,
    this._keyStore,
    this._cancelAllAlarms, {
    @ignoreParam LocalDataOperationGate? operationGate,
  }) : _operationGate = operationGate ?? LocalDataOperationGate.shared;

  final AppDatabase _database;
  final InstallationKeyStore _keyStore;
  final CancelAllAlarmsUseCase _cancelAllAlarms;
  final LocalDataOperationGate _operationGate;

  Future<void> reset() => _operationGate.run(_reset, replacesData: true);

  Future<void> _reset() async {
    await LocalDataLifecycle.markResetPending();
    // The durable reset intent is now irrevocable in this process. Even if
    // cleanup fails, do not reopen normal writers; bootstrap resumes reset.
    _operationGate.invalidate();
    await _cancelAllAlarms.forDataReplacement();
    await NotificationService.instance.cancelAll();
    await _database.close();
    await deleteLocalDatabaseFiles(includeLegacy: true);
    await (await SharedPreferences.getInstance()).clear();
    await _keyStore.delete();
    // The pending marker is intentionally cleared by bootstrap on next launch.
  }
}
