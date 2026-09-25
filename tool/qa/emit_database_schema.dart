// Run with flutter test. Output is an explicit external baseline, never copied
// over historical contracts by this command or by the application generator.
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';

void main() {
  test('emit current schema to the explicitly requested baseline path', () async {
    final output = Platform.environment['ONTIME_SCHEMA_OUTPUT'];
    if (output == null) throw StateError('ONTIME_SCHEMA_OUTPUT is required');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await db.customSelect('SELECT 1').get();
      final rows = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT GLOB 'sqlite_*' ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 ELSE 2 END,name",
          )
          .get();
      await File(output).writeAsString(
        '${rows.map((r) => r.read<String>('sql')).join(';\n')};\nPRAGMA user_version=${db.schemaVersion};\n',
      );
      final engine = await db
          .customSelect('SELECT sqlite_version() AS version')
          .getSingle();
      await File('$output.engine.json').writeAsString(jsonEncode(engine.data));
    } finally {
      await db.close();
    }
  });
}
