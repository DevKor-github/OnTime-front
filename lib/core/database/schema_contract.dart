import 'dart:convert';
import 'package:collection/collection.dart';
import 'schema_contracts.g.dart';

/// Immutable release contracts, embedded by build_runner without runtime I/O.
final class DatabaseSchemaContract {
  DatabaseSchemaContract._();
  static final Map<String, dynamic> _data =
      jsonDecode(databaseSchemaContractsJson) as Map<String, dynamic>;
  static int get current => _data['current'] as int;
  static List<int> get legacySupported =>
      List<int>.from(_data['legacySupported'] as List);
  static List<int> get pairSupported =>
      List<int>.from(_data['pairSupported'] as List);
  static const equality = DeepCollectionEquality();
  static const objectsQuery =
      "SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT GLOB 'sqlite_*' AND sql IS NOT NULL ORDER BY type,name";

  static void validate(int version, List<Map<String, Object?>> objects) {
    final snapshot = (_data['snapshots'] as List)
        .cast<Map<String, dynamic>>()
        .where((s) => s['version'] == version)
        .singleOrNull;
    if (snapshot == null) throw const UnsupportedDatabaseSchema();
    final expected = _shape(
      (snapshot['objects'] as List)
          .map((o) => Map<String, Object?>.from(o as Map))
          .toList(),
    );
    if (!equality.equals(_shape(objects), expected)) {
      throw const UnsupportedDatabaseSchema();
    }
  }

  static Map<String, dynamic> _tables(int version) =>
      ((_data['snapshots'] as List).cast<Map<String, dynamic>>().singleWhere(
            (s) => s['version'] == version,
          )['tables']
          as Map<String, dynamic>);

  static void validateTableMetadata(
    int version,
    String table,
    List<Map<String, Object?>> columns,
    List<Map<String, Object?>> foreignKeys,
    List<Map<String, Object?>> indexes,
  ) {
    final expected = _tables(version)[table] as Map<String, dynamic>?;
    if (expected == null) throw const UnsupportedDatabaseSchema();
    List<Map<String, Object?>> columnShape(List<Map<String, Object?>> rows) =>
        rows
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
            .toList()
          ..sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
    List<String> foreignShape(List<Map<String, Object?>> rows) {
      final groups = <Object?, List<Map<String, Object?>>>{};
      for (final row in rows) {
        (groups[row['id']] ??= []).add({
          for (final k in [
            'seq',
            'table',
            'from',
            'to',
            'on_update',
            'on_delete',
            'match',
          ])
            k: row[k],
        });
      }
      return groups.values.map((group) {
        group.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
        return jsonEncode(group);
      }).toList()..sort();
    }

    List<Map<String, Object?>> castRows(Object? value) => (value as List)
        .map((r) => Map<String, Object?>.from(r as Map))
        .toList();
    List<String> indexShape(List<Map<String, Object?>> rows) =>
        rows
            .map(
              (r) => jsonEncode({
                'unique': r['unique'],
                'origin': r['origin'],
                'partial': r['partial'],
                'columns': castRows(r['columns'])
                    .map(
                      (c) => {
                        for (final k in [
                          'seqno',
                          'name',
                          'desc',
                          'coll',
                          'key',
                        ])
                          k: c[k],
                      },
                    )
                    .toList(),
              }),
            )
            .toList()
          ..sort();
    if (!equality.equals(
          columnShape(columns),
          columnShape(castRows(expected['columns'])),
        ) ||
        !equality.equals(
          foreignShape(foreignKeys),
          foreignShape(castRows(expected['foreignKeys'])),
        ) ||
        !equality.equals(
          indexShape(indexes),
          indexShape(castRows(expected['indexes'])),
        )) {
      throw const UnsupportedDatabaseSchema();
    }
  }

  static List<Object> _shape(List<Map<String, Object?>> objects) {
    final rows = <List<Object>>[];
    for (final object in objects) {
      final type = object['type'];
      final name = object['name'];
      final table = object['tbl_name'];
      final sql = object['sql'];
      if (type is! String ||
          name is! String ||
          table is! String ||
          sql is! String) {
        throw const UnsupportedDatabaseSchema();
      }
      final tokens = sqlTokens(sql);
      Object body = tokens;
      if (type == 'table') {
        final start = tokens.indexOf('(');
        if (start < 0 || tokens.last != ')') {
          throw const UnsupportedDatabaseSchema();
        }
        // ALTER TABLE appends columns after the table's PK clause. Column
        // ordinals do not define this application's explicit-column queries.
        // Order *inside* PK/FK/UNIQUE/CHECK expressions remains significant.
        final clauses = <String>[];
        var depth = 0;
        var currentClause = <String>[];
        for (final token in tokens.sublist(start + 1, tokens.length - 1)) {
          if (token == ',' && depth == 0) {
            clauses.add(jsonEncode(currentClause));
            currentClause = [];
          } else {
            if (token == '(') depth++;
            if (token == ')') depth--;
            if (depth < 0) throw const UnsupportedDatabaseSchema();
            currentClause.add(token);
          }
        }
        if (depth != 0) throw const UnsupportedDatabaseSchema();
        clauses.add(jsonEncode(currentClause));
        clauses.sort();
        body = [tokens.sublist(0, start), clauses];
      }
      rows.add([type, name, table, body]);
    }
    rows.sort((a, b) => '${a[0]}:${a[1]}'.compareTo('${b[0]}:${b[1]}'));
    return rows;
  }
}

final class UnsupportedDatabaseSchema implements Exception {
  const UnsupportedDatabaseSchema();
  @override
  String toString() => 'Local database schema requires recovery';
}

/// A lexical comparison, not whitespace stripping. String literal contents and
/// expression/group order are retained. Uncertain syntax is refused.
List<String> sqlTokens(String sql) {
  final result = <String>[];
  var i = 0;
  while (i < sql.length) {
    final char = sql[i];
    if (RegExp(r'\s').hasMatch(char)) {
      i++;
      continue;
    }
    if (i + 1 < sql.length && sql.substring(i, i + 2) == '--') {
      final end = sql.indexOf('\n', i + 2);
      i = end < 0 ? sql.length : end + 1;
      continue;
    }
    if (i + 1 < sql.length && sql.substring(i, i + 2) == '/*') {
      final end = sql.indexOf('*/', i + 2);
      if (end < 0) throw const UnsupportedDatabaseSchema();
      i = end + 2;
      continue;
    }
    if (char == "'" || char == '"' || char == '`' || char == '[') {
      final close = char == '[' ? ']' : char;
      var value = '';
      var ended = false;
      i++;
      while (i < sql.length) {
        if (sql[i] == close) {
          if (char != '[' && i + 1 < sql.length && sql[i + 1] == close) {
            value += close;
            i += 2;
            continue;
          }
          i++;
          ended = true;
          break;
        }
        value += sql[i++];
      }
      if (!ended) throw const UnsupportedDatabaseSchema();
      result.add(char == "'" ? 's:$value' : 'q:$value');
      continue;
    }
    if (RegExp(r'[A-Za-z_]').hasMatch(char)) {
      final begin = i++;
      while (i < sql.length && RegExp(r'[A-Za-z_0-9]').hasMatch(sql[i])) {
        i++;
      }
      result.add('w:${sql.substring(begin, i).toLowerCase()}');
      continue;
    }
    if (RegExp(r'[0-9]').hasMatch(char)) {
      final begin = i++;
      while (i < sql.length && RegExp(r'[0-9.]').hasMatch(sql[i])) {
        i++;
      }
      result.add('n:${sql.substring(begin, i)}');
      continue;
    }
    if ('(),;=<>!+-*/.%|&~'.contains(char)) {
      if (char != ';' || i != sql.length - 1) result.add(char);
      i++;
      continue;
    }
    throw const UnsupportedDatabaseSchema();
  }
  return result;
}
