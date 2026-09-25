import 'dart:convert';
import 'package:build/build.dart';
import 'package:crypto/crypto.dart';
import 'database_schema_input.dart';

Builder databaseSchemaContracts(BuilderOptions options) => _SchemaBuilder();

class _SchemaBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
    '.schema.json': ['.g.dart'],
  };
  @override
  Future<void> build(BuildStep step) async {
    final source = await step.readAsString(step.inputId);
    await validateDatabaseSchemaInput(
      jsonDecode(source) as Map<String, dynamic>,
      (path) => step.readAsBytes(AssetId(step.inputId.package, path)),
    );
    final encoded = jsonEncode(source).replaceAll(r'$', r'\$');
    final output = AssetId(
      step.inputId.package,
      step.inputId.path.replaceFirst(RegExp(r'\.schema\.json$'), '.g.dart'),
    );
    await step.writeAsString(
      output,
      '// GENERATED CODE - DO NOT MODIFY BY HAND\n'
      '// Created only by database_schema_contracts build_runner builder.\n'
      'const databaseSchemaContractsDigest = "${sha256.convert(utf8.encode(source))}";\n'
      'const databaseSchemaContractsJson = $encoded;\n',
    );
  }
}
