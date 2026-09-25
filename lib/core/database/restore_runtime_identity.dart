import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache of installation-local DB authority, loaded before runtime consumers.
/// The backup revision is deliberately not used as a replacement epoch.
final class RestoreRuntimeIdentity {
  static final shared = RestoreRuntimeIdentity();
  String? storeIncarnation;
  bool rejectLegacy = false;
  bool _pending = false;
  Object _loadOwner = Object();

  bool get pending => _pending;
  set pending(bool value) {
    // A replacement hold supersedes every read that started before it.
    _loadOwner = Object();
    _pending = value;
  }

  bool accepts(Object? identity) =>
      !pending &&
      (identity == null ? !rejectLegacy : identity == storeIncarnation);

  Future<void> load(AppDatabase database) async {
    final owner = Object();
    _loadOwner = owner;
    final row = await (database.select(
      database.users,
    )..where((t) => t.id.equals(localProfileId))).getSingleOrNull();
    if (!identical(owner, _loadOwner)) return;
    storeIncarnation = row?.storeIncarnation;
    rejectLegacy = row?.rejectLegacyDelivery ?? false;
    _pending = row?.restoreCleanupPending ?? false;
  }

  /// Pre-DI distinguishes an unreadable store from a known restore receipt.
  Future<void> prepareStartup(
    AppDatabase database,
    LocalDataOperationGate gate, {
    required Future<void> Function() cleanupPlatform,
  }) async {
    try {
      await load(database);
    } catch (cause) {
      throw RestoreStoreUnavailable(cause);
    }
    if (!pending) {
      gate.setRecoveryPending(false);
      return;
    }
    try {
      await cleanup(database, gate, cleanupPlatform: cleanupPlatform);
    } catch (cause) {
      throw RestoreRecoveryRequired(cause);
    }
  }

  Future<void> cleanup(
    AppDatabase database,
    LocalDataOperationGate gate, {
    required Future<void> Function() cleanupPlatform,
    bool releaseGate = true,
  }) async {
    await load(database);
    gate.setRecoveryPending(!releaseGate || pending);
    if (!pending) return;
    final identity = storeIncarnation;
    if (identity == null) throw StateError('Restore identity unavailable');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    for (final key
        in prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith('preparation_with_time_') ||
                  key.startsWith('early_start_session_'),
            )
            .toList()) {
      if (!await prefs.remove(key)) {
        throw StateError('Restore runtime cleanup pending');
      }
    }
    await prefs.reload();
    if (prefs.getKeys().any(
      (key) =>
          key.startsWith('preparation_with_time_') ||
          key.startsWith('early_start_session_'),
    )) {
      throw StateError('Restore runtime cleanup unconfirmed');
    }
    await cleanupPlatform();
    await database.transaction(() async {
      final changed =
          await (database.update(database.users)..where(
                (t) =>
                    t.id.equals(localProfileId) &
                    t.storeIncarnation.equals(identity),
              ))
              .write(const UsersCompanion(restoreCleanupPending: Value(false)));
      if (changed != 1) throw StateError('Restore identity changed');
      final row = await (database.select(
        database.users,
      )..where((t) => t.id.equals(localProfileId))).getSingle();
      if (row.storeIncarnation != identity || row.restoreCleanupPending) {
        throw StateError('Restore cleanup commit unconfirmed');
      }
    });
    await load(database);
    gate.setRecoveryPending(!releaseGate || pending);
  }
}

final class RestoreRecoveryRequired implements Exception {
  const RestoreRecoveryRequired(this.cause);
  final Object cause;
}

final class RestoreStoreUnavailable implements Exception {
  const RestoreStoreUnavailable(this.cause);
  final Object cause;
}
