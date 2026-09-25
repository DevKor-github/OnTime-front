// Actual authenticated ingestion and host SQLCipher pair files. Platform cleanup
// is an awaited owner callback; these are not native OS delivery tests.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/recovery/pair_files.dart';
import 'package:on_time_front/core/database/recovery/pair_key_store.dart';
import 'package:on_time_front/core/database/recovery/recovery_restore_service.dart';
import 'package:on_time_front/core/database/recovery/store_pair.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import '../../helpers/sodium_test_loader.dart';
import '../backup/backup_validation_contract_test.dart' show validBackup;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
  const password = 'recovery time review password';
  const legacy = StorePair.legacy();
  const firstProcess = '10000000-0000-4000-8000-000000000001';
  const nextProcess = '10000000-0000-4000-8000-000000000002';
  final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
  late Directory directory;
  late PairFiles files;
  late LocalDataOperationGate gate;
  late AlarmOperationCoordinator alarmOwner;
  late BackupProcessingOwner processing;
  late DateTime now;
  late String process;
  var cleanups = 0;
  Future<void> Function()? onCleanup;
  Future<void> Function(String)? fault;
  final selections = <BackupRestoreSelection>[];
  RecoveryRestoreService service() => RecoveryRestoreService(
    files,
    crypto: crypto,
    now: () => now,
    gate: gate,
    owner: alarmOwner,
    processingOwner: processing,
    processIdentity: () async => process,
    ingestionFactory: (b) => BackupIngestionStore.create(
      b,
      root: Directory('${directory.path}/ingestion'),
    ),
    cleanupPlatform: () async {
      cleanups++;
      await onCleanup?.call();
    },
    repairCutover: () async {},
  );
  setUpAll(() {
    if (library != null) {
      open.overrideForAll(() => DynamicLibrary.open(library));
    }
  });
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('a10-recovery-time-');
    files = PairFiles(
      directory,
      PairKeyStore(),
      protect: (_) async {},
      checkpoint: (name) async => fault?.call(name),
    );
    gate = LocalDataOperationGate();
    alarmOwner = AlarmOperationCoordinator(gate);
    processing = BackupProcessingOwner();
    now = DateTime.utc(2030);
    process = firstProcess;
    cleanups = 0;
    onCleanup = null;
    fault = null;
    selections.clear();
    await files.database(legacy).writeAsString('damaged original preserved');
  });
  tearDown(() async {
    fault = null;
    onCleanup = null;
    for (final value in selections.reversed) {
      await value.dispose();
    }
    alarmOwner.dispose();
    gate.dispose();
    await directory.delete(recursive: true);
  });
  Future<Uint8List> encrypted({bool unknown = true}) async {
    final input = jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
    input['schedules'][0].addAll({
      'civilTime': '2031-01-02T09:00:00.123456',
      'timeZoneId': unknown ? 'Removed/Zone' : 'UTC',
      'occurrenceOffsetSeconds': 0,
    });
    return crypto.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(input))),
      password: password,
    );
  }

  Future<RecoveryCandidate> ready(RecoveryRestoreService port) async {
    final input =
        await port.reviewBytes(await encrypted(), password)
            as BackupTimeReviewInput;
    selections.add(input);
    final issue = (await input.issues()).items.single;
    final summary = input.summary;
    final review = await input.review(
      BackupTimeDraft(
        identity: summary.identity,
        revision: summary.revision,
        rulesIdentity: summary.rulesIdentity,
        issueId: issue.id,
        civil: issue.civil,
        zone: 'UTC',
      ),
    );
    await input.choose(BackupTimeChoice(review: review, offsetSeconds: 0));
    final selected = await input.revalidate();
    selections.add(selected);
    return selected as RecoveryCandidate;
  }

  final stale = isA<DataOperationException>().having(
    (e) => e.failure,
    'failure',
    DataOperationFailure.stalePreview,
  );
  group(
    'SQLCipher recovery authenticated time review',
    () {
      test(
        'review has no pair record or key and explicit choice produces owned encrypted ready only',
        () async {
          final port = service();
          final bytes = await encrypted();
          final original = List<int>.of(bytes);
          final input =
              await port.reviewBytes(bytes, password) as BackupTimeReviewInput;
          selections.add(input);
          expect(await files.readRecord(), isNull);
          expect(await files.readManifest(), isNull);
          expect(await files.keys.hasHistory(), isFalse);
          expect(cleanups, 0);
          expect(gate.generation, 0);
          expect(
            await files.database(legacy).readAsString(),
            'damaged original preserved',
          );
          final issue = (await input.issues()).items.single;
          final summary = input.summary;
          final choice = await input.review(
            BackupTimeDraft(
              identity: summary.identity,
              revision: summary.revision,
              rulesIdentity: summary.rulesIdentity,
              issueId: issue.id,
              civil: issue.civil,
              zone: 'UTC',
            ),
          );
          await input.choose(
            BackupTimeChoice(review: choice, offsetSeconds: 0),
          );
          final candidate = await input.revalidate() as RecoveryCandidate;
          selections.add(candidate);
          expect((await files.readRecord())!.stage, PairStage.validated);
          expect(await files.readManifest(), isNull);
          expect(cleanups, 0);
          final db = await port.openPair(candidate.record.target);
          try {
            final row = await db
                .customSelect(
                  'SELECT schedule_time, time_zone_id, occurrence_offset_seconds FROM schedules',
                )
                .getSingle();
            expect(row.data['schedule_time'], '2031-01-02T09:00:00.123456');
            expect(row.data['time_zone_id'], 'UTC');
            expect(row.data['occurrence_offset_seconds'], 0);
          } finally {
            await db.close();
          }
          expect(bytes, original);
          await input.dispose();
          expect(processing.active, isNotNull);
          await candidate.dispose();
          expect(processing.active, isNull);
          expect(await files.readRecord(), isNull);
        },
      );
      for (final rewind in [false, true]) {
        test(
          'ready expiry before claim has no generation or cleanup (rewind=$rewind)',
          () async {
            final port = service();
            final candidate = await ready(port);
            now = rewind ? DateTime.utc(2029) : DateTime.utc(2032);
            await expectLater(port.activate(candidate), throwsA(stale));
            expect(gate.generation, 0);
            expect(cleanups, 0);
            expect((await files.readRecord())!.confirmed, isFalse);
            expect(await files.readManifest(), isNull);
          },
        );
      }
      test(
        'expiry during cleanup keeps unconfirmed data and retry cannot activate',
        () async {
          final port = service();
          final candidate = await ready(port);
          final barrier = Completer<void>();
          final entered = Completer<void>();
          onCleanup = () async {
            entered.complete();
            await barrier.future;
          };
          final pending = port.activate(candidate);
          await entered.future;
          now = DateTime.utc(2032);
          barrier.complete();
          await expectLater(
            pending,
            throwsA(
              stale
                  .having((e) => e.followUpPending, 'cleanup pending', true)
                  .having((e) => e.generation, 'generation', 1),
            ),
          );
          expect((await files.readRecord())!.confirmed, isFalse);
          expect(gate.isRecoveryPending, isFalse);
          expect(await files.readManifest(), isNull);
          expect(
            await files.database(legacy).readAsString(),
            'damaged original preserved',
          );
          await expectLater(port.retryPreclaimCleanup(0), throwsA(stale));
          onCleanup = () async {
            throw StateError('cleanup failed');
          };
          await expectLater(
            port.retryPreclaimCleanup(1),
            throwsA(
              stale.having(
                (e) => e.followUpPending,
                'retry still pending',
                true,
              ),
            ),
          );
          onCleanup = null;
          await port.retryPreclaimCleanup(1);
          expect(cleanups, 3);
          expect((await files.readRecord())!.confirmed, isFalse);
          expect(await files.readManifest(), isNull);
          expect(await files.keys.hasHistory(), isFalse);
        },
      );
      test(
        'original evidence changes during review prevent candidate construction',
        () async {
          final port = service();
          final input =
              await port.reviewBytes(await encrypted(), password)
                  as BackupTimeReviewInput;
          selections.add(input);
          final issue = (await input.issues()).items.single;
          final summary = input.summary;
          final choice = await input.review(
            BackupTimeDraft(
              identity: summary.identity,
              revision: summary.revision,
              rulesIdentity: summary.rulesIdentity,
              issueId: issue.id,
              civil: issue.civil,
              zone: 'UTC',
            ),
          );
          await input.choose(
            BackupTimeChoice(review: choice, offsetSeconds: 0),
          );
          await files.database(legacy).writeAsString('externally changed');
          await expectLater(input.revalidate(), throwsA(stale));
          expect(await files.readRecord(), isNull);
          expect(cleanups, 0);
        },
      );
      test(
        'confirmed intent remains durable when clock advances and new process resumes',
        () async {
          final port = service();
          final candidate = await ready(port);
          fault = (step) async {
            if (step == 'record.confirmed.renamed') {
              now = DateTime.utc(2032);
              throw StateError('lost durable confirmation response');
            }
          };
          final receipt = await port.activate(candidate);
          expect(receipt.followUpPending, isTrue);
          expect((await files.readRecord())!.confirmed, isTrue);
          expect(cleanups, 1);
          fault = null;
          process = nextProcess;
          final resumed = await service().resume();
          expect(resumed.disposition, BackupCommitDisposition.committed);
          expect(resumed.followUpPending, isFalse);
          expect(await files.readManifest(), candidate.record.target);
        },
      );
      test('strict preview checks future authority after ready too', () async {
        final port = service();
        final candidate = await port.previewBytes(
          await encrypted(unknown: false),
          password,
        );
        selections.add(candidate);
        now = DateTime.utc(2032);
        await expectLater(port.activate(candidate), throwsA(stale));
        expect(gate.generation, 0);
        expect(cleanups, 0);
      });
    },
    skip: library == null
        ? 'Set ONTIME_TEST_SQLCIPHER_LIBRARY for actual encrypted pair proof'
        : false,
  );
}
