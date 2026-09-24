import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:on_time_front/core/database/local_data_files.dart';
import 'package:on_time_front/core/database/local_reset_actions.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_registry_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class LocalResetRecoveryRequired implements Exception {
  const LocalResetRecoveryRequired(this.result);
  final LocalResetResult result;
}

final class LocalDataLifecycle {
  static const _storage = FlutterSecureStorage();
  static const _cutoverMarker = 'ontime_local_only_cutover_v1';
  static const _legacyTokenKeys = ['accessToken', 'refreshToken'];
  static const _legacyIosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static Future<LocalResetResult>? _resetInFlight;

  static Future<void> bootstrap() async {
    final reset = await resumeReset();
    if (reset.recoveryRequired) throw LocalResetRecoveryRequired(reset);
    if (await _storage.read(key: _cutoverMarker) == null) {
      await _performOneWayCutover();
    }
  }

  static Future<void> markResetPending() =>
      DeviceLocalResetActions().writeMarker();

  /// No DB or DI is opened while an interrupted reset remains unconfirmed.
  static Future<LocalResetResult> resumeReset() {
    final running = _resetInFlight;
    if (running != null) return running;
    final owner = AlarmOperationCoordinator.shared;
    _resetInFlight = owner
        .cleanup(() {
          final registry = AlarmRegistryRepositoryImpl(
            localDataSource: AlarmRegistryLocalDataSourceImpl(),
          );
          return LocalResetProtocol(
            owner.journal,
            AlarmRegistrationCleanup(
              registry,
              AlarmSchedulerService(),
              FallbackAlarmNotificationServiceImpl(),
              owner,
            ),
            DeviceLocalResetActions(),
          ).run(begin: false);
        })
        .whenComplete(() => _resetInFlight = null);
    return _resetInFlight!;
  }

  static Future<void> _performOneWayCutover() async {
    await deleteLocalDatabaseFiles(includeLegacy: true);
    if (!await (await SharedPreferences.getInstance()).clear()) {
      throw StateError('Local cutover preferences cleanup failed');
    }
    for (final key in _legacyTokenKeys) {
      await _storage.delete(key: key);
      await _storage.delete(key: key, iOptions: _legacyIosOptions);
    }
    await _storage.write(key: _cutoverMarker, value: 'complete');
  }
}
