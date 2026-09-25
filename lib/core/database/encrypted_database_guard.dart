import 'package:sqlite3/sqlite3.dart';
import 'schema_contract.dart';

enum DatabaseOpenRole {
  legacyStartup,
  activePairStartup,
  candidateValidation,
  ownedCreation,
}

/// Shared SQLCipher and schema guard; it never creates keys or rewrites files.
void guardEncryptedDatabase(
  Database raw,
  String keyHex, {
  required DatabaseOpenRole role,
  bool allowCreation = false,
}) {
  final cipher = raw.select('PRAGMA cipher_version');
  if (cipher.length != 1 ||
      cipher.single.values.length != 1 ||
      cipher.single.values.single is! String ||
      (cipher.single.values.single as String).trim().isEmpty) {
    throw const EncryptedDatabaseUnavailable();
  }
  if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(keyHex)) {
    throw const EncryptedDatabaseUnavailable();
  }
  raw.execute('PRAGMA key = "x\'$keyHex\'"');
  // Reading the schema/version, not merely accepting PRAGMA key, verifies the
  // actual engine/key/file combination before Drift obtains migration authority.
  final version = raw.userVersion;
  final objects = raw
      .select(DatabaseSchemaContract.objectsQuery)
      .map((row) => Map<String, Object?>.from(row))
      .toList();
  if (version == 0) {
    if (!allowCreation ||
        objects.isNotEmpty ||
        (role != DatabaseOpenRole.ownedCreation &&
            role != DatabaseOpenRole.legacyStartup)) {
      throw const UnsupportedDatabaseSchema();
    }
  } else {
    final allowed = switch (role) {
      DatabaseOpenRole.legacyStartup => DatabaseSchemaContract.legacySupported,
      DatabaseOpenRole.activePairStartup =>
        DatabaseSchemaContract.pairSupported,
      DatabaseOpenRole.candidateValidation => [DatabaseSchemaContract.current],
      DatabaseOpenRole.ownedCreation => const <int>[],
    };
    if (!allowed.contains(version)) throw const UnsupportedDatabaseSchema();
    DatabaseSchemaContract.validate(version, objects);
    for (final object in objects.where((o) => o['type'] == 'table')) {
      final name = object['name'] as String;
      final quoted = '"${name.replaceAll('"', '""')}"';
      final indexes = <Map<String, Object?>>[];
      for (final index in raw.select('PRAGMA index_list($quoted)')) {
        final indexName =
            '"${(index['name'] as String).replaceAll('"', '""')}"';
        indexes.add({
          ...index,
          'columns': raw
              .select('PRAGMA index_xinfo($indexName)')
              .map((r) => Map<String, Object?>.from(r))
              .toList(),
        });
      }
      DatabaseSchemaContract.validateTableMetadata(
        version,
        name,
        raw.select('PRAGMA table_xinfo($quoted)'),
        raw.select('PRAGMA foreign_key_list($quoted)'),
        indexes,
      );
    }
    if (raw.select('PRAGMA quick_check').single.values.single != 'ok' ||
        raw.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw const UnsupportedDatabaseSchema();
    }
  }
  // Connection-local settings do not grant migration or creation authority.
  raw.execute('PRAGMA cipher_memory_security = ON');
  raw.execute('PRAGMA temp_store = MEMORY');
}

final class EncryptedDatabaseUnavailable implements Exception {
  const EncryptedDatabaseUnavailable();
  @override
  String toString() => 'Encrypted local database requires recovery';
}
