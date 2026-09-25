import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class EarlyStartSessionLocalDataSource {
  Future<void> saveSession({
    required String scheduleId,
    required DateTime startedAt,
  });

  Future<DateTime?> loadSessionStartedAt(String scheduleId);

  Future<void> clearSession(String scheduleId);
}

@Injectable(as: EarlyStartSessionLocalDataSource)
class EarlyStartSessionLocalDataSourceImpl
    implements EarlyStartSessionLocalDataSource {
  static const String _prefsKeyPrefix = 'early_start_session_';

  @override
  Future<void> saveSession({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    final identity = RestoreRuntimeIdentity.shared;
    final incarnation = identity.storeIncarnation;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$scheduleId';
    final payload = jsonEncode({
      'startedAt': startedAt.millisecondsSinceEpoch,
      'storeIncarnation': ?incarnation,
    });
    if (!identity.accepts(incarnation)) throw StateError('Old runtime owner');
    if (!await prefs.setString(key, payload)) {
      throw StateError('Early preparation start was not saved');
    }
  }

  @override
  Future<DateTime?> loadSessionStartedAt(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$scheduleId';
    final payload = prefs.getString(key);
    if (payload == null) return null;

    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (!RestoreRuntimeIdentity.shared.accepts(map['storeIncarnation'])) {
        return null;
      }
      final startedAtMillis = (map['startedAt'] as num?)?.toInt();
      if (startedAtMillis == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(startedAtMillis);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearSession(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$scheduleId';
    if (!await prefs.remove(key)) {
      throw StateError('Early start cleanup pending');
    }
  }
}
