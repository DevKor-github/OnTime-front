import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:sqlite3/sqlite3.dart';

// Branch-input evidence only. Actual engine and mobile proofs are separate.
void main() {
  for (final entry in <String, List<List<Object?>>>{
    'no rows': [],
    'null': [
      [null],
    ],
    'empty': [
      [''],
    ],
    'whitespace': [
      ['  '],
    ],
    'nonstring': [
      [4],
    ],
    'multiple rows': [
      ['4'],
      ['4'],
    ],
  }.entries) {
    test('${entry.key} capability refuses before key/schema/write', () {
      final raw = _CapabilityOnlyDatabase(
        ResultSet(['cipher_version'], null, entry.value),
      );
      expect(
        () => guardEncryptedDatabase(
          raw,
          '09' * 32,
          role: DatabaseOpenRole.legacyStartup,
        ),
        throwsA(isA<EncryptedDatabaseUnavailable>()),
      );
      expect(raw.calls, ['PRAGMA cipher_version']);
    });
  }
  test('capability query error escapes before key/schema/write', () {
    final raw = _CapabilityOnlyDatabase(null);
    expect(
      () => guardEncryptedDatabase(
        raw,
        '09' * 32,
        role: DatabaseOpenRole.legacyStartup,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(raw.calls, ['PRAGMA cipher_version']);
  });
}

class _CapabilityOnlyDatabase implements Database {
  _CapabilityOnlyDatabase(this.result);
  final ResultSet? result;
  final calls = <String>[];
  @override
  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    calls.add(sql);
    if (sql != 'PRAGMA cipher_version') {
      throw StateError('Schema access forbidden');
    }
    return result ?? (throw SqliteException(1, 'capability query fault'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Key/write/access forbidden: ${invocation.memberName}');
}
