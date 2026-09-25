import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/database/schema_contract.dart';
import 'package:on_time_front/presentation/startup/screens/local_startup_gate.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  testWidgets(
    'actual future store reaches pre-DI recovery without normal app or alarms',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final directory = Directory.systemTemp.createTempSync('d04-shell-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/store.sqlite');
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute(
        File('test/fixtures/database/schema_v4.sql').readAsStringSync(),
      );
      raw.execute(
        File('test/fixtures/database/populated_local.sql').readAsStringSync(),
      );
      raw.userVersion = DatabaseSchemaContract.current + 1;
      raw.dispose();
      final before = file.readAsBytesSync();
      final gate = LocalDataOperationGate();
      addTearDown(gate.dispose);
      AppDatabase? attempt;
      var normalCalls = 0;
      var alarms = 0;
      var attempts = 0;
      Object? classified;
      await tester.pumpWidget(
        LocalStartupGate(
          prepare: () async {
            attempts++;
            attempt = AppDatabase.forTesting(NativeDatabase(file));
            try {
              await RestoreRuntimeIdentity().prepareStartup(
                attempt!,
                gate,
                cleanupPlatform: () async {
                  alarms++;
                },
              );
              alarms++; // Represents normal notification bootstrap after store authority.
            } catch (error) {
              classified = error;
              rethrow;
            }
          },
          cleanupAttempt: () async {
            await attempt?.close();
            attempt = null;
          },
          ready: () {
            normalCalls++;
            return const SizedBox();
          },
          beginReset: () => throw StateError('No implicit reset'),
          retryReset: () => throw StateError('No reset intent'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        classified,
        isA<RestoreStoreUnavailable>().having(
          (e) => e.cause,
          'actual migration refusal',
          isA<UnsupportedDatabaseSchema>(),
        ),
      );
      expect(find.text('Reset all local data'), findsOneWidget);
      expect(normalCalls, 0);
      expect(alarms, 0);
      expect(file.readAsBytesSync(), before);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(normalCalls, 0);
      expect(alarms, 0);
      expect(file.readAsBytesSync(), before);
      final reopened = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      expect(reopened.userVersion, DatabaseSchemaContract.current + 1);
      expect(
        reopened.select('SELECT note FROM users').single['note'],
        '합성 프로필  공백',
      );
      reopened.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
