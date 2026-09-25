import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';

final class DetailedNotificationPreferenceSnapshot {
  const DetailedNotificationPreferenceSnapshot({
    required this.generation,
    required this.detailedEnabled,
    required this.scheduleNotificationsEnabled,
  });
  final int generation;
  final bool detailedEnabled;
  final bool scheduleNotificationsEnabled;
}

final class DetailedNotificationProfileUnavailable implements Exception {
  const DetailedNotificationProfileUnavailable();
}

abstract interface class DetailedNotificationPreferencePort {
  Future<DetailedNotificationPreferenceSnapshot> read({
    required int expectedGeneration,
  });
  Future<DetailedNotificationPreferenceSnapshot> write(
    bool enabled, {
    required int expectedGeneration,
  });
}

@lazySingleton
class DetailedNotificationPreferenceService
    implements DetailedNotificationPreferencePort {
  DetailedNotificationPreferenceService(
    this._database, {
    @ignoreParam LocalDataOperationGate? gate,
  }) : _gate = gate ?? LocalDataOperationGate.shared;

  final AppDatabase _database;
  final LocalDataOperationGate _gate;

  @override
  Future<DetailedNotificationPreferenceSnapshot> read({
    required int expectedGeneration,
  }) async {
    _gate.checkWrite(expectedGeneration);
    final row = await (_database.select(
      _database.users,
    )..where((user) => user.id.equals(localProfileId))).getSingleOrNull();
    _gate.checkWrite(expectedGeneration);
    if (row == null) throw const DetailedNotificationProfileUnavailable();
    return DetailedNotificationPreferenceSnapshot(
      generation: expectedGeneration,
      detailedEnabled: row.detailedNotificationContent,
      scheduleNotificationsEnabled: row.alarmsEnabled,
    );
  }

  @override
  Future<DetailedNotificationPreferenceSnapshot> write(
    bool enabled, {
    required int expectedGeneration,
  }) {
    _gate.checkWrite(expectedGeneration);
    return _database.writeTransaction(() async {
      _gate.checkWrite(expectedGeneration);
      await _database.userDao.updateDetailedNotificationContent(
        userId: localProfileId,
        enabled: enabled,
      );
      return read(expectedGeneration: expectedGeneration);
    }, gate: _gate);
  }

  // Retained for callers outside the settings controller; both are strict.
  Future<bool> getEnabled() async =>
      (await read(expectedGeneration: _gate.generation)).detailedEnabled;
  Future<void> setEnabled(bool enabled) async {
    await write(enabled, expectedGeneration: _gate.generation);
  }
}
