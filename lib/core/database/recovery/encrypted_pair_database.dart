import '../encrypted_database_guard.dart';
import '../schema_contract.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:drift/native.dart';
import '../database.dart';
import '../sqlcipher_loader.dart';
import 'pair_files.dart';
import 'store_pair.dart';

Future<AppDatabase> openEncryptedPair(
  PairFiles files,
  StorePair pair, {
  bool creating = false,
  bool startupMigration = false,
}) async {
  final file = files.database(pair);
  await files.regular(file.path);
  if (!await file.exists()) throw const PairAuthorityUnavailable();
  if (!creating) await files.requireExisting(pair);
  final key = await files.keys.read(pair);
  if (key == null) throw const PairAuthorityUnavailable();
  configureSqlCipherLoader();
  final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final db = AppDatabase.forTesting(
    NativeDatabase(
      file,
      setup: (raw) {
        guardEncryptedDatabase(
          raw,
          hex,
          role: creating
              ? DatabaseOpenRole.ownedCreation
              : startupMigration
              ? DatabaseOpenRole.activePairStartup
              : DatabaseOpenRole.candidateValidation,
          allowCreation: creating,
        );
      },
    ),
  );
  try {
    await db.customSelect('SELECT count(*) FROM sqlite_master').get();
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}

/// Reads an existing original without running Drift migrations, creating a DB,
/// or changing its runtime. A now-readable store requires normal A09 confirmation.
Future<bool> originalPairReadable(PairFiles files, StorePair pair) async {
  final file = files.database(pair);
  await files.regular(file.path);
  if (!await file.exists() || await file.length() == 0) return false;
  final List<int>? key;
  try {
    key = await files.keys.read(pair);
  } on PairAuthorityUnavailable {
    return false;
  }
  if (key == null) return false;
  configureSqlCipherLoader();
  final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    guardEncryptedDatabase(
      raw,
      hex,
      role: pair.isLegacy
          ? DatabaseOpenRole.legacyStartup
          : DatabaseOpenRole.activePairStartup,
    );
    final version = raw.userVersion;
    if (version < 3) {
      final profiles = raw.select('SELECT id FROM users');
      return pair.isLegacy &&
          profiles.length == 1 &&
          profiles.single['id'] == 'local-profile';
    }
    if (version == 3) {
      final profiles = raw.select('SELECT id, store_incarnation FROM users');
      return pair.isLegacy &&
          profiles.length == 1 &&
          profiles.single['id'] == 'local-profile' &&
          profiles.single['store_incarnation'] is String &&
          RegExp(
            r'^[a-f0-9]{32}$',
          ).hasMatch(profiles.single['store_incarnation'] as String);
    }
    final rows = raw.select(
      'SELECT id, store_incarnation, reject_legacy_delivery, restore_cleanup_pending FROM users',
    );
    if (rows.length != 1) return false;
    final row = rows.single;
    final runtime = row['store_incarnation'];
    final reject = row['reject_legacy_delivery'];
    final pending = row['restore_cleanup_pending'];
    return row['id'] == 'local-profile' &&
        runtime is String &&
        RegExp(r'^[a-f0-9]{32}$').hasMatch(runtime) &&
        (reject == 0 || reject == 1) &&
        (pending == 0 || pending == 1) &&
        (pair.isLegacy || reject == 1) &&
        (pending == 0 || reject == 1);
  } on SqliteException {
    return false;
  } on UnsupportedDatabaseSchema {
    return false;
  } on EncryptedDatabaseUnavailable {
    return false;
  } finally {
    raw.dispose();
  }
}
