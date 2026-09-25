// Installed only in the separate D04 QA bundle. Uses synthetic data/key slots.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:on_time_front/core/database/schema_contract.dart';
import 'package:on_time_front/core/database/schema_contracts.g.dart';
import 'package:on_time_front/core/database/sqlcipher_loader.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('D04 synthetic migration probe')),
      ),
    ),
  );
  final documents = await getApplicationDocumentsDirectory();
  final result = File('${documents.path}/d04-result.json');
  final rows = <Map<String, Object?>>[];
  var phase = 'initializing';
  final ownedSlots = <String>[];
  const storage = FlutterSecureStorage();
  const options = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  try {
    configureSqlCipherLoader();
    final session = DateTime.now().microsecondsSinceEpoch;
    final directory = Directory('${documents.path}/synthetic-$session');
    await directory.create();
    for (final version in DatabaseSchemaContract.legacySupported) {
      phase = 'schema-$version';
      final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final slot = 'd04-synthetic-$session-v$version';
      ownedSlots.add(slot);
      await storage.write(key: slot, value: hex, iOptions: options);
      if (await storage.read(key: slot, iOptions: options) != hex) {
        throw StateError('QA key readback failed');
      }
      final file = File('${directory.path}/v$version.sqlite');
      final original = sqlite.sqlite3.open(file.path);
      guardEncryptedDatabase(
        original,
        hex,
        role: DatabaseOpenRole.ownedCreation,
        allowCreation: true,
      );
      final cipher =
          original.select('PRAGMA cipher_version').single.values.single
              as String;
      final engine =
          original.select('SELECT sqlite_version()').single.values.single
              as String;
      original.execute(
        await rootBundle.loadString('fixtures/schema_v$version.sql'),
      );
      original.execute(
        await rootBundle.loadString('fixtures/populated_local.sql'),
      );
      if (version >= 2) {
        original.execute(
          await rootBundle.loadString('fixtures/populated_recurring.sql'),
        );
      }
      final image = <String, List<Map<String, Object?>>>{};
      for (final row in original.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT GLOB 'sqlite_*'",
      )) {
        final name = row['name'] as String;
        image[name] = original
            .select('SELECT * FROM "$name" ORDER BY rowid')
            .map((r) => Map<String, Object?>.from(r))
            .toList();
      }
      original.dispose();
      for (var reopening = 0; reopening < 2; reopening++) {
        final db = AppDatabase.forTesting(
          NativeDatabase.createInBackground(
            file,
            isolateSetup: configureSqlCipherLoader,
            setup: (raw) => guardEncryptedDatabase(
              raw,
              hex,
              role: DatabaseOpenRole.legacyStartup,
            ),
          ),
        );
        try {
          final current =
              (await db.customSelect('PRAGMA user_version').getSingle())
                  .read<int>('user_version');
          if (current != DatabaseSchemaContract.current) {
            throw StateError('Schema version mismatch');
          }
          for (final entry in image.entries) {
            final fields = entry.value.first.keys.map((k) => '"$k"').join(',');
            final actual =
                (await db
                        .customSelect(
                          'SELECT $fields FROM "${entry.key}" ORDER BY rowid',
                        )
                        .get())
                    .map((r) => r.data)
                    .toList();
            if (!DatabaseSchemaContract.equality.equals(actual, entry.value)) {
              throw StateError('Historical row image changed');
            }
          }
        } finally {
          await db.close();
        }
      }
      for (final attemptedKey in <String?>[null, 'incorrect synthetic key']) {
        final raw = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        var rejected = false;
        try {
          if (attemptedKey != null) raw.execute("PRAGMA key = '$attemptedKey'");
          raw.select('SELECT note FROM users');
        } on sqlite.SqliteException {
          rejected = true;
        } finally {
          raw.dispose();
        }
        if (!rejected) throw StateError('Missing/wrong key accepted');
      }
      final path = file.path;
      final plainRejected = Platform.isAndroid
          ? await const MethodChannel(
                  'ontime.d04.qa',
                ).invokeMethod<bool>('ordinarySQLiteRejects', path) ??
                false
          : await Isolate.run(() {
              open.overrideForAll(
                () => DynamicLibrary.open('/usr/lib/libsqlite3.dylib'),
              );
              final raw = sqlite.sqlite3.open(
                path,
                mode: sqlite.OpenMode.readOnly,
              );
              try {
                if (raw.select('PRAGMA cipher_version').isNotEmpty) {
                  return false;
                }
                raw.select('SELECT note FROM users');
                return false;
              } on sqlite.SqliteException {
                return true;
              } finally {
                raw.dispose();
              }
            });
      if (!plainRejected) {
        throw StateError('Ordinary system SQLite refusal not proved');
      }
      await storage.delete(key: slot, iOptions: options);
      if (await storage.read(key: slot, iOptions: options) != null) {
        throw StateError('Owned QA key cleanup readback failed');
      }
      rows.add({
        'from': version,
        'to': DatabaseSchemaContract.current,
        'originalTables': image.length,
        'backgroundOpenCount': 2,
        'cipherVersion': cipher,
        'sqliteVersion': engine,
        'syntheticSecureStorageReadback': true,
        'ownedKeyDeletionReadback': true,
        'wrongAndMissingKeyRejected': true,
        'ordinarySQLiteRejected': true,
      });
    }
    await result.writeAsString(
      jsonEncode({
        'success': true,
        'platform': Platform.operatingSystem,
        'contractDigest': databaseSchemaContractsDigest,
        'scope':
            'dedicated QA bundle using product AppDatabase/guards and background isolate',
        'physicalDeviceVerified': false,
        'productMainDiVerified': false,
        'powerLossVerified': false,
        'results': rows,
      }),
      flush: true,
    );
  } catch (error) {
    await result.writeAsString(
      jsonEncode({
        'success': false,
        'phase': phase,
        'errorType': error.runtimeType.toString(),
        'completed': rows,
      }),
      flush: true,
    );
  } finally {
    for (final slot in ownedSlots) {
      await storage.delete(key: slot, iOptions: options);
    }
  }
}
