// Synthetic host SQLCipher/process-death proof; never opens installed app data.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:on_time_front/core/services/alarm_journal_store_native.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:sqlite3/open.dart';

import '../../test/helpers/schedule_deletion_workflow_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'committed deletion and file ownership survive actual host process death',
    () async {
      final directory = Platform.environment['U01_PROBE_DIR'];
      final mode = Platform.environment['U01_PROBE_MODE'];
      final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
      if (directory == null ||
          library == null ||
          !['cut', 'recover'].contains(mode)) {
        throw StateError('Explicit synthetic probe environment required');
      }
      final recovering = mode == 'recover';
      open.overrideForAll(() => DynamicLibrary.open(library));
      final db = AppDatabase.forTesting(
        NativeDatabase(
          File('$directory/store.sqlite'),
          setup: (raw) => guardEncryptedDatabase(
            raw,
            '0909090909090909090909090909090909090909090909090909090909090909',
            role: recovering
                ? DatabaseOpenRole.activePairStartup
                : DatabaseOpenRole.ownedCreation,
            allowCreation: !recovering,
          ),
        ),
      );
      final fixture = DeletionWorkflowFixture(
        database: db,
        journalStore: FileAlarmJournalStore(
          () async => Directory('$directory/journal'),
        ),
      );
      addTearDown(fixture.close);
      if (!recovering) {
        await fixture.open();
        await fixture.create();
        fixture.registry.records = [fixture.record('one', 71)];
        final before = await fixture.revision();
        fixture.fallback.onCancel = (_) async {
          expect(await db.select(db.schedules).get(), isEmpty);
          expect(await fixture.revision(), before + 1);
          final journal = await fixture.owner.journal.read();
          expect(journal.ownership, hasLength(1));
          final raw = await File(
            '$directory/journal/ownership-v1.json',
          ).readAsString();
          expect(raw, isNot(contains('private')));
          File('$directory/cut-ready').writeAsStringSync(
            jsonEncode({
              'point': 'after-commit-before-provider-return',
              'cutTestPid': pid,
              'revision': before + 1,
            }),
            flush: true,
          );
          await Completer<void>().future;
        };
        await fixture.deletion.confirm(await fixture.deletion.prepare('one'));
        fail('Provider checkpoint did not block');
      }
      final checkpoint =
          jsonDecode(File('$directory/cut-ready').readAsStringSync())
              as Map<String, dynamic>;
      expect(await db.select(db.schedules).get(), isEmpty);
      expect(await db.select(db.preparationSchedules).get(), isEmpty);
      expect(await db.select(db.places).get(), isEmpty);
      expect(await fixture.revision(), checkpoint['revision']);
      expect((await fixture.owner.journal.read()).ownership, hasLength(1));
      expect(fixture.registry.records, isEmpty);
      // Production shared recovery primitive, under a fresh owner. The complete
      // mobile bootstrap/provider integration remains a separate device condition.
      final cleanup = AlarmRegistrationCleanup(
        fixture.registry,
        fixture.scheduler,
        fixture.fallback,
        fixture.owner,
      );
      final report = await fixture.owner.run(
        fixture.owner.capture(),
        () => cleanup.cancelMatchingReport(scheduleId: 'one'),
      );
      expect(report.isComplete, isTrue);
      expect(
        fixture.fallback.cancelled.map(
          (record) => record.fallbackNotificationId,
        ),
        [71],
      );
      expect((await fixture.owner.journal.read()).ownership, isEmpty);
      expect(await fixture.revision(), checkpoint['revision']);
      expect(await db.select(db.schedules).get(), isEmpty);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      final cipher =
          (await db.customSelect('PRAGMA cipher_version').getSingle())
              .data
              .values
              .single;
      expect(cipher, isA<String>());
      File('$directory/verified').writeAsStringSync(
        jsonEncode({
          'recoverTestPid': pid,
          'cipherVersion': cipher,
          'actualCipher': true,
          'deletedRowsRemainAbsent': true,
          'replayedOwnership': 1,
          'revisionUnchangedDuringRecovery': true,
          'provider': 'fake local notification port',
          'recoveryScope':
              'production shared cleanup primitive; not full mobile bootstrap',
          'mobileOsVerified': false,
          'powerLossVerified': false,
        }),
        flush: true,
      );
    },
  );
}
