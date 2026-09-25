import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/schema_contract.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  for (final version in DatabaseSchemaContract.legacySupported) {
    test('independent schema $version matches its complete contract', () {
      final db = sqlite3.openInMemory();
      try {
        db.execute(
          File(
            'test/fixtures/database/schema_v$version.sql',
          ).readAsStringSync(),
        );
        DatabaseSchemaContract.validate(
          version,
          db.select(DatabaseSchemaContract.objectsQuery),
        );
        // LIKE sqlite_% would incorrectly hide this legal, unknown table.
        db.execute('CREATE TABLE sqlitex_probe (id INTEGER)');
        expect(
          () => DatabaseSchemaContract.validate(
            version,
            db.select(DatabaseSchemaContract.objectsQuery),
          ),
          throwsA(isA<UnsupportedDatabaseSchema>()),
        );
      } finally {
        db.dispose();
      }
    });
  }
  test('lexer preserves string whitespace and escaped quote identity', () {
    expect(
      sqlTokens("CHECK (name = 'a  b')"),
      isNot(sqlTokens("CHECK(name='a b')")),
    );
    expect(
      sqlTokens('CHECK ("flag" IN (0, 1))'),
      sqlTokens(' check("flag" in(0,1)) '),
    );
    expect(sqlTokens("DEFAULT 'don''t , (x)'"), contains("s:don't , (x)"));
    expect(
      sqlTokens('PRIMARY KEY (first, second)'),
      isNot(sqlTokens('PRIMARY KEY (second, first)')),
    );
    expect(
      sqlTokens('FOREIGN KEY(a,b) REFERENCES t(x,y)'),
      isNot(sqlTokens('FOREIGN KEY(b,a) REFERENCES t(x,y)')),
    );
    expect(sqlTokens('UNIQUE(a,b)'), isNot(sqlTokens('UNIQUE(b,a)')));
    expect(
      () => sqlTokens("DEFAULT 'unterminated"),
      throwsA(isA<UnsupportedDatabaseSchema>()),
    );
  });
  test('quoted fallback strings preserve case as actual SQLite does', () {
    final db = sqlite3.openInMemory();
    try {
      expect(
        db.select('SELECT "notEnded"=\'notEnded\'').single.values.single,
        1,
      );
      expect(
        db.select('SELECT "NOTENDED"=\'notEnded\'').single.values.single,
        0,
      );
      expect(
        sqlTokens('DEFAULT "notEnded"'),
        isNot(sqlTokens('DEFAULT "NOTENDED"')),
      );
    } finally {
      db.dispose();
    }
  });
  test('quoted NULL is not the NULL keyword in an actual identity trigger', () {
    final db = sqlite3.openInMemory();
    try {
      db.execute(
        File('test/fixtures/database/schema_v4.sql').readAsStringSync(),
      );
      final original =
          db
                  .select(
                    "SELECT sql FROM sqlite_master WHERE name='users_identity'",
                  )
                  .single['sql']
              as String;
      db.execute('DROP TRIGGER users_identity');
      db.execute(original.replaceFirst('IS NULL BEGIN', 'IS "NULL" BEGIN'));
      db.execute(
        "INSERT INTO users(id,spare_time,note) VALUES('local-profile',0,'synthetic')",
      );
      expect(
        db
            .select('SELECT store_incarnation FROM users')
            .single['store_incarnation'],
        isNull,
      );
      expect(
        () => DatabaseSchemaContract.validate(
          4,
          db.select(DatabaseSchemaContract.objectsQuery),
        ),
        throwsA(isA<UnsupportedDatabaseSchema>()),
      );
    } finally {
      db.dispose();
    }
  });
  for (final change in ['literal', 'check', 'index', 'trigger', 'column']) {
    test(
      'current contract unit comparison rejects copied schema descriptors with altered $change',
      () {
        final db = sqlite3.openInMemory();
        try {
          db.execute(
            File('test/fixtures/database/schema_v4.sql').readAsStringSync(),
          );
          final objects = db
              .select(DatabaseSchemaContract.objectsQuery)
              .map((r) => Map<String, Object?>.from(r))
              .toList();
          if (change == 'index' || change == 'trigger') {
            objects.removeWhere((r) => r['type'] == change);
          } else {
            final row = objects.singleWhere((r) => r['name'] == 'schedules');
            row['sql'] = switch (change) {
              'literal' => (row['sql'] as String).replaceAll(
                "'notEnded'",
                "'not Ended'",
              ),
              'check' => (row['sql'] as String).replaceAll(
                'IN (0, 1)',
                'IN (0, 1, 2)',
              ),
              _ => (row['sql'] as String).replaceFirst(
                'TEXT NOT NULL',
                'TEXT NULL',
              ),
            };
          }
          expect(
            () => DatabaseSchemaContract.validate(4, objects),
            throwsA(isA<UnsupportedDatabaseSchema>()),
          );
          DatabaseSchemaContract.validate(
            4,
            db.select(DatabaseSchemaContract.objectsQuery),
          );
        } finally {
          db.dispose();
        }
      },
    );
  }
}
