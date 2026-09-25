import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/initial_store_guard_native.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/startup/startup_failure.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
  if (library != null) open.overrideForAll(() => DynamicLibrary.open(library));
  test(
    'first creation receipt finishes only after real cipher/schema; reopen keeps original bytes and key',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('ontime-d01-cipher-');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/ontime_local_v1.sqlite');
      final keys = InstallationKeyStore();
      InitialStoreGuard guard() =>
          InitialStoreGuard(file, keys, protect: (_) async {});
      final first = await guard().prepareOpen();
      String hex(List<int> key) =>
          key.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      AppDatabase database(List<int> key) => AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) {
            raw.execute('PRAGMA key = "x\'${hex(key)}\'"');
            expect(raw.select('PRAGMA cipher_version'), isNotEmpty);
          },
        ),
      );
      final initial = database(first);
      await initial
          .into(initial.users)
          .insert(
            UsersCompanion.insert(spareTime: 7, note: 'D01-SYNTHETIC-PRIVATE'),
          );
      await initial.close();
      expect(await guard().receiptFile.exists(), true);
      // Simulated process interruption after cipher/schema, before completion.
      final second = await guard().prepareOpen();
      expect(base64Encode(second) == base64Encode(first), true);
      final reopened = database(second);
      expect(
        (await reopened.select(reopened.users).getSingle()).note,
        'D01-SYNTHETIC-PRIVATE',
      );
      await reopened.close();
      await guard().completeVerifiedCreation();
      expect(await guard().receiptFile.exists(), false);
      final bytes = await file.readAsBytes();
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('D01-SYNTHETIC-PRIVATE')),
      );
      expect(
        utf8.decode(bytes.take(16).toList(), allowMalformed: true),
        isNot(startsWith('SQLite format 3')),
      );
      for (final wrongKey in [null, 'wrong-key']) {
        final raw = sqlite.sqlite3.open(file.path);
        try {
          if (wrongKey != null) raw.execute("PRAGMA key = '$wrongKey'");
          expect(
            () => raw.select('SELECT note FROM users'),
            throwsA(isA<sqlite.SqliteException>()),
          );
        } finally {
          raw.dispose();
        }
      }
      await keys.delete();
      await expectLater(
        guard().prepareOpen().then((_) => true),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      expect(
        base64Encode(await file.readAsBytes()) == base64Encode(bytes),
        true,
      );
      expect(await keys.exists(), false);
    },
    skip: library == null
        ? 'Requires actual SQLCipher host library; not mobile keystore evidence'
        : false,
  );
}
