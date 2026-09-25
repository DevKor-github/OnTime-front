import 'recovery/pair_files.dart';
import 'package:on_time_front/core/database/initial_store_guard.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/startup/startup_failure.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
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

  static Future<void> bootstrap({Future<void> Function()? preparePairs}) async {
    final reset = await resumeReset();
    if (reset.recoveryRequired) throw LocalResetRecoveryRequired(reset);
    await preparePairs?.call();
    // Pair authority is resolved before fixed-store/cutover classification.
    final pair = await (await PairFiles.device()).selected();
    if (!pair.isLegacy) return;
    final String? marker;
    try {
      marker = await _storage.read(key: _cutoverMarker);
    } catch (_) {
      throw const LocalStorePreservationRequired();
    }
    if (marker != null && marker != 'complete') {
      throw const LocalStorePreservationRequired();
    }
    if (marker == null) {
      await (await InitialStoreGuard.device(
        InstallationKeyStore(),
      )).requireNoLocalEvidence();
      await _performOneWayCutover();
    }
  }

  /// Only called after the explicit restored pair was opened and verified by
  /// recovery startup. Never the normal marker-error fallback.
  static Future<void> repairCutoverAfterVerifiedRestore() async {
    final marker = await _storage.read(key: _cutoverMarker);
    if (marker == 'complete') return;
    await deleteLegacyDatabaseFiles();
    for (final key in _legacyTokenKeys) {
      await _storage.delete(key: key);
      await _storage.delete(key: key, iOptions: _legacyIosOptions);
      if (await _storage.read(key: key) != null ||
          await _storage.read(key: key, iOptions: _legacyIosOptions) != null) {
        throw const LocalStorePreservationRequired();
      }
    }
    await _storage.write(key: _cutoverMarker, value: 'complete');
    if (await _storage.read(key: _cutoverMarker) != 'complete') {
      throw const LocalStorePreservationRequired();
    }
  }

  static Future<void> markResetPending() =>
      DeviceLocalResetActions().writeMarker();

  /// No DB or DI is opened while an interrupted reset remains unconfirmed.
  static Future<LocalResetResult> resumeReset() => _reset(begin: false);

  /// Called only after the recovery UI has obtained destructive confirmation.
  static Future<LocalResetResult> beginReset() {
    if (LocalDataOperationGate.shared.isRecoveryPending) {
      return Future.error(const LocalDataUnavailable());
    }
    return _reset(begin: true);
  }

  static bool _resetBegin = false;
  static Future<LocalResetResult> _reset({required bool begin}) {
    final running = _resetInFlight;
    if (running != null) {
      if (begin && !_resetBegin) throw StateError('Reset recovery is busy');
      return running;
    }
    _resetBegin = begin;
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
            onIntent: LocalDataOperationGate.shared.invalidate,
          ).run(begin: begin);
        })
        .whenComplete(() => _resetInFlight = null);
    return _resetInFlight!;
  }

  static Future<void> _performOneWayCutover() async {
    await deleteLegacyDatabaseFiles();
    if (!await (await SharedPreferences.getInstance()).clear()) {
      throw StateError('Local cutover preferences cleanup failed');
    }
    for (final key in _legacyTokenKeys) {
      await _storage.delete(key: key);
      await _storage.delete(key: key, iOptions: _legacyIosOptions);
    }
    await _storage.write(key: _cutoverMarker, value: 'complete');
    if (await _storage.read(key: _cutoverMarker) != 'complete') {
      throw const LocalStorePreservationRequired();
    }
  }
}
