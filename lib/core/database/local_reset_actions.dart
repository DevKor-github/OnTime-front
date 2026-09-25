import 'recovery/pair_files.dart';
import 'package:on_time_front/core/database/initial_store_guard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_files.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Destructive adapters are shared by live reset and pre-database recovery.
/// A completed stage means its read-back succeeded, not just its API call.
final class DeviceLocalResetActions
    implements LocalResetActions, ResetGlobalDeliveryCleanup {
  DeviceLocalResetActions({
    FlutterSecureStorage? storage,
    InstallationKeyStore? keyStore,
    this.closeDatabase,
    Future<void> Function()? deleteFiles,
    Future<void> Function()? removeCreationReceipt,
    Future<void> Function()? removePairKeys,
    Future<void> Function()? clearDeliveries,
    Future<bool> Function()? clearNativeDeliveries,
    Future<void> Function()? clearLaunch,
  }) : storage = storage ?? const FlutterSecureStorage(),
       keyStore = keyStore ?? InstallationKeyStore(),
       deleteFiles =
           deleteFiles ??
           (() async {
             await (await PairFiles.device()).resetFiles();
             await deleteLocalDatabaseFiles(includeLegacy: true);
           }),
       removePairKeys =
           removePairKeys ??
           (() async => (await PairFiles.device()).resetKeysAndMetadata()),
       removeCreationReceipt =
           removeCreationReceipt ?? InitialStoreGuard.removeDeviceReceipt,
       clearDeliveries = clearDeliveries ?? _clearDeliveries,
       clearNativeDeliveries = clearNativeDeliveries ?? _clearNativeDeliveries,
       clearLaunch = clearLaunch ?? _clearLaunch;

  static const resetMarker = 'ontime_local_reset_pending_v1';
  static const legacyTokenKeys = ['accessToken', 'refreshToken'];
  static const _legacyIosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  final FlutterSecureStorage storage;
  final InstallationKeyStore keyStore;
  final Future<void> Function()? closeDatabase;
  final Future<void> Function() deleteFiles;
  final Future<void> Function() removeCreationReceipt;
  final Future<void> Function() removePairKeys;
  final Future<void> Function() clearDeliveries;
  final Future<bool> Function() clearNativeDeliveries;
  bool _allProvidersConfirmedEmpty = false;
  @override
  bool get allProvidersConfirmedEmpty => _allProvidersConfirmedEmpty;
  final Future<void> Function() clearLaunch;

  @override
  Future<bool> hasMarker() async =>
      await storage.read(key: resetMarker) != null;
  @override
  Future<void> writeMarker() async {
    await storage.write(key: resetMarker, value: 'pending');
    if (!await hasMarker()) throw const AlarmJournalUnavailable();
  }

  @override
  Future<void> removeMarker() async {
    await storage.delete(key: resetMarker);
    if (await hasMarker()) throw const AlarmJournalUnavailable();
  }

  @override
  Future<void> perform(ResetStep step) async {
    switch (step) {
      case ResetStep.deliveries:
        _allProvidersConfirmedEmpty = false;
        final nativeConfirmed = await clearNativeDeliveries();
        await clearDeliveries();
        _allProvidersConfirmedEmpty = nativeConfirmed;
      case ResetStep.database:
        await closeDatabase?.call();
        await deleteFiles();
        await removeCreationReceipt();
      case ResetStep.preferences:
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.clear()) throw const AlarmJournalUnavailable();
        await prefs.reload();
        if (prefs.getKeys().isNotEmpty) throw const AlarmJournalUnavailable();
      case ResetStep.key:
        await removePairKeys();
        await keyStore.delete();
        if (await keyStore.exists()) throw const AlarmJournalUnavailable();
      case ResetStep.credentials:
        for (final key in legacyTokenKeys) {
          await storage.delete(key: key);
          await storage.delete(key: key, iOptions: _legacyIosOptions);
          if (await storage.read(key: key) != null ||
              await storage.read(key: key, iOptions: _legacyIosOptions) !=
                  null) {
            throw const AlarmJournalUnavailable();
          }
        }
      case ResetStep.launch:
        await clearLaunch();
    }
  }

  static Future<bool> _clearNativeDeliveries() async =>
      await const MethodChannel(
        'on_time_front/native_alarm',
      ).invokeMethod<bool>('resetCancelAllNativeAlarms') ==
      true;

  static Future<void> _clearDeliveries() async {
    final notifications = NotificationService.instance;
    await notifications.cancelAll();
    final remaining = await notifications.observePendingScheduleNotifications();
    if (!remaining.available || remaining.entries.isNotEmpty) {
      throw const AlarmJournalUnavailable();
    }
  }

  static Future<void> _clearLaunch() async {
    await const MethodChannel(
      'on_time_front/native_alarm',
    ).invokeMethod<void>('clearStoredLaunchPayload');
  }
}
