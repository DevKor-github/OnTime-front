import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_files.dart';
import 'package:on_time_front/core/database/local_data_lifecycle.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class LocalDataResetService {
  LocalDataResetService(this._database, this._keyStore, this._cancelAllAlarms);

  final AppDatabase _database;
  final InstallationKeyStore _keyStore;
  final CancelAllAlarmsUseCase _cancelAllAlarms;

  Future<void> reset() async {
    await LocalDataLifecycle.markResetPending();
    await _cancelAllAlarms().catchError((_) {});
    await NotificationService.instance.cancelAll().catchError((_) {});
    await _database.close();
    await deleteLocalDatabaseFiles(includeLegacy: true);
    await (await SharedPreferences.getInstance()).clear();
    await _keyStore.delete();
    // The pending marker is intentionally cleared by bootstrap on next launch.
  }
}
