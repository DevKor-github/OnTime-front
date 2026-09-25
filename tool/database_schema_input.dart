import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// Tool-only: execute the frozen DDL in isolated memory, then compare every
/// schema object and PRAGMA descriptor. No product model or database is used.
Future<void> validateDatabaseSchemaInput(
  Map<String, dynamic> data,
  Future<List<int>> Function(String path) read,
) async {
  if (data['format'] != 1 || data['current'] is! int) {
    throw StateError('Invalid schema format/current');
  }
  final snapshots = data['snapshots'];
  if (snapshots is! List || snapshots.isEmpty) {
    throw StateError('Missing snapshots');
  }
  final versions = <int>{};
  const equality = DeepCollectionEquality();
  for (final entry in snapshots) {
    if (entry is! Map<String, dynamic>) throw StateError('Invalid snapshot');
    final version = entry['version'];
    if (version is! int ||
        version < 1 ||
        !versions.add(version) ||
        entry['sourceCommit'] is! String ||
        !RegExp(r'^[a-f0-9]{40}$').hasMatch(entry['sourceCommit'] as String) ||
        entry['engine'] is! String ||
        (entry['engine'] as String).isEmpty) {
      throw StateError('Invalid schema provenance/version');
    }
    final path = entry['ddlPath'];
    if (path != 'test/fixtures/database/schema_v$version.sql') {
      throw StateError('Invalid schema fixture path');
    }
    final bytes = await read(path as String);
    if (sha256.convert(bytes).toString() != entry['ddlSha256']) {
      throw StateError('Historical schema $version digest mismatch');
    }
    final raw = sqlite3.openInMemory();
    try {
      raw.execute(utf8.decode(bytes));
      if (raw.userVersion != version) throw StateError('DDL version mismatch');
      final objects = raw.select(
        "SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT GLOB 'sqlite_*' AND sql IS NOT NULL ORDER BY type,name",
      );
      final tables = <String, Object>{};
      for (final object in objects.where((o) => o['type'] == 'table')) {
        final name = object['name'] as String;
        final quoted = '"${name.replaceAll('"', '""')}"';
        final indexes = <Map<String, Object?>>[];
        for (final index in raw.select('PRAGMA index_list($quoted)')) {
          final iq = '"${(index['name'] as String).replaceAll('"', '""')}"';
          indexes.add({
            'unique': index['unique'],
            'origin': index['origin'],
            'partial': index['partial'],
            'columns': raw
                .select('PRAGMA index_xinfo($iq)')
                .map(
                  (r) => {
                    for (final k in ['seqno', 'name', 'desc', 'coll', 'key'])
                      k: r[k],
                  },
                )
                .toList(),
          });
        }
        tables[name] = {
          'columns': raw
              .select('PRAGMA table_xinfo($quoted)')
              .map(
                (r) => {
                  for (final k in [
                    'name',
                    'type',
                    'notnull',
                    'dflt_value',
                    'pk',
                    'hidden',
                  ])
                    k: r[k],
                },
              )
              .toList(),
          'foreignKeys': raw
              .select('PRAGMA foreign_key_list($quoted)')
              .map((r) => Map<String, Object?>.from(r))
              .toList(),
          'indexes': indexes,
        };
      }
      if (!equality.equals(
            objects.map((r) => Map<String, Object?>.from(r)).toList(),
            entry['objects'],
          ) ||
          !equality.equals(tables, entry['tables'])) {
        throw StateError('Snapshot $version does not describe its actual DDL');
      }
    } finally {
      raw.dispose();
    }
  }
  Set<int> checkedVersions(Object? value) {
    if (value is! List || value.isEmpty || value.any((v) => v is! int)) {
      throw StateError('Invalid supported versions');
    }
    final set = value.cast<int>().toSet();
    if (set.length != value.length ||
        !set.contains(data['current']) ||
        !set.every(versions.contains)) {
      throw StateError('Missing/duplicate supported schema');
    }
    return set;
  }

  final legacy = checkedVersions(data['legacySupported']);
  final pair = checkedVersions(data['pairSupported']);
  if (legacy.length != versions.length ||
      pair.any((v) => v < 4) ||
      versions.any((v) => v > (data['current'] as int))) {
    throw StateError('Invalid supported schema lineage');
  }
}
