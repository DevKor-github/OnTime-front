import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:on_time_front/core/database/schema_contracts.g.dart';
import 'database_schema_input.dart';

Future<void> main() async {
  try {
    const path = 'lib/core/database/schema_contracts.schema.json';
    final source = await File(path).readAsString();
    await validateDatabaseSchemaInput(
      jsonDecode(source) as Map<String, dynamic>,
      (path) => File(path).readAsBytes(),
    );
    if (databaseSchemaContractsDigest !=
            sha256.convert(utf8.encode(source)).toString() ||
        databaseSchemaContractsJson != source) {
      throw StateError(
        'Generated schema contracts are stale; run build_runner',
      );
    }
    stdout.writeln(
      'Historical schema contracts, DDL, lineage and generated digest agree.',
    );
  } catch (error) {
    stderr.writeln('Database schema gate failed: $error');
    exitCode = 1;
  }
}
