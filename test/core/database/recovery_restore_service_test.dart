import '../backup/backup_validation_contract_test.dart' show validBackup;
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/restore_staging_fixture.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/presentation/startup/screens/local_startup_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:on_time_front/core/backup/backup_content.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/recovery/encrypted_pair_database.dart';
import 'package:on_time_front/core/database/recovery/pair_files.dart';
import 'package:on_time_front/core/database/recovery/pair_key_store.dart';
import 'package:on_time_front/core/database/recovery/recovery_restore_service.dart';
import 'package:on_time_front/core/database/recovery/store_pair.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const origin = '10000000-0000-4000-8000-000000000001';
  const next = '10000000-0000-4000-8000-000000000002';
  const password = 'portable backup password';
  const legacy = StorePair.legacy();
  final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
  late Directory directory;
  late PairFiles files;
  late BackupProcessingOwner processingOwner;
  late LocalDataOperationGate gate;
  late AlarmOperationCoordinator owner;
  var process = origin;
  var repairs = 0;
  final crypto = BackupCrypto();
  late Uint8List backup;
  Future<void> Function(String)? fault;
  RecoveryRestoreService service() => RecoveryRestoreService(
    files,
    crypto: crypto,
    processingOwner: processingOwner,
    ingestionFactory: (b) => BackupIngestionStore.create(
      b,
      root: Directory('${directory.path}/ingestion'),
    ),
    gate: gate,
    owner: owner,
    processIdentity: () async => process,
    cleanupPlatform: () async {},
    repairCutover: () async {
      repairs++;
    },
  );
  setUpAll(() async {
    if (library != null) {
      open.overrideForAll(() => DynamicLibrary.open(library));
    }
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'restored private note',
      ),
    );
    final content = await BackupContent.capture(
      db,
      cutoff: DateTime.utc(2030),
      sourceAppVersion: 'test',
      sourcePlatform: 'android',
    );
    backup = await crypto.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(content.toJson()))),
      password: password,
    );
    await db.close();
  });
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('d02-service-');
    processingOwner = BackupProcessingOwner();
    fault = null;
    files = PairFiles(
      directory,
      PairKeyStore(),
      protect: (_) async {},
      checkpoint: (step) async => fault?.call(step),
    );
    gate = LocalDataOperationGate();
    owner = AlarmOperationCoordinator(gate);
    process = origin;
    repairs = 0;
    await files
        .database(legacy)
        .writeAsString('damaged original encrypted bytes');
  });
  tearDown(() async {
    owner.dispose();
    gate.dispose();
    await directory.delete(recursive: true);
  });
  test(
    'known original manifest cannot progress confirmed intent by query alone',
    () async {
      final a = StorePair.candidate('00000000-0000-4000-8000-000000000001');
      final b = StorePair.candidate('00000000-0000-4000-8000-000000000002');
      await files.writeRecord(
        PairRecord(
          target: b,
          original: a,
          originProcess: origin,
          stage: PairStage.confirmed,
          originalEvidence: await files.evidence(a),
          runtimeIdentity: '1' * 32,
        ),
      );
      await files.publish(a);
      await files.keys.markHistory();
      process = next;
      final recovery = service();
      for (var i = 0; i < 2; i++) {
        final receipt = await recovery.resume();
        expect(receipt.disposition, BackupCommitDisposition.notCommitted);
        expect(receipt.followUpPending, true);
        expect(await files.readManifest(), a);
      }
      expect(gate.isRecoveryPending, true);
    },
  );
  test(
    'existing reset intent forbids candidate allocation under the shared owner',
    () async {
      final state = await owner.journal.read();
      state.reset = ResetPhase.pending;
      await owner.journal.save(state);
      await expectLater(
        service().previewBytes(backup, password),
        throwsA(isA<LocalDataUnavailable>()),
      );
      expect(await files.readRecord(), null);
      expect(
        await files.database(legacy).readAsString(),
        'damaged original encrypted bytes',
      );
    },
  );
  group(
    'real host SQLCipher',
    () {
      test(
        'recovery cold reopen and activation preserve foreign civil gap raw text',
        () async {
          final input = validBackup();
          input['schedules'][0]['civilTime'] = '2026-03-08T02:30:00.123456';
          final encrypted = await crypto.encrypt(
            plaintext: Uint8List.fromList(utf8.encode(jsonEncode(input))),
            password: password,
          );
          final recovery = service();
          final candidate = await recovery.previewBytes(encrypted, password);
          var db = await openEncryptedPair(files, candidate.record.target);
          expect(
            (await db
                    .customSelect('SELECT schedule_time FROM schedules')
                    .getSingle())
                .read<String>('schedule_time'),
            '2026-03-08T02:30:00.123456',
          );
          await db.close();
          expect(
            (await recovery.activate(candidate)).disposition,
            BackupCommitDisposition.committed,
          );
          db = await openEncryptedPair(files, candidate.record.target);
          expect(
            (await db
                    .customSelect('SELECT schedule_time FROM schedules')
                    .getSingle())
                .read<String>('schedule_time'),
            '2026-03-08T02:30:00.123456',
          );
          await db.close();
          expect(
            await files.database(legacy).readAsString(),
            'damaged original encrypted bytes',
          );
        },
      );
      Future<PairRecord> ready() async {
        final recovery = service();
        final candidate = await recovery.previewBytes(backup, password);
        await recovery.activate(candidate);
        process = next;
        await service().prepareStartup();
        return (await files.readRecord())!;
      }

      for (final failure in ['before', 'after', 'readBack']) {
        test(
          'first history marker $failure failure keeps exact intent and resumes safely',
          () async {
            final storage = _HistoryFault();
            files = PairFiles(
              directory,
              PairKeyStore(storage: storage),
              protect: (_) async {},
            );
            final recovery = service();
            final candidate = await recovery.previewBytes(backup, password);
            storage.mode = failure;
            final receipt = await recovery.activate(candidate);
            if (failure == 'after') {
              expect(receipt.disposition, BackupCommitDisposition.committed);
            } else {
              expect(receipt.disposition, BackupCommitDisposition.undetermined);
              expect(await files.readManifest(), null);
            }
            expect(storage.writes, 1);
            expect(await files.database(legacy).exists(), true);
            storage.mode = '';
            process = next;
            if (failure == 'before') {
              await expectLater(
                service().prepareStartup(),
                throwsA(isA<PairRecoveryRequired>()),
              );
              expect(await files.readManifest(), null);
            }
            expect((await service().resume()).followUpPending, false);
            expect(await files.readManifest(), candidate.record.target);
          },
        );
      }
      for (final marker in ['future', '2']) {
        test(
          'invalid history $marker is preserved and never overwritten',
          () async {
            final storage = _HistoryFault();
            files = PairFiles(
              directory,
              PairKeyStore(storage: storage),
              protect: (_) async {},
            );
            final recovery = service();
            final candidate = await recovery.previewBytes(backup, password);
            storage.mode = 'before';
            expect(
              (await recovery.activate(candidate)).disposition,
              BackupCommitDisposition.undetermined,
            );
            storage.mode = '';
            await files.keys.storage.write(
              key: PairKeyStore.historyKey,
              value: marker,
            );
            await expectLater(
              files.keys.markHistory(),
              throwsA(isA<PairAuthorityUnavailable>()),
            );
            process = next;
            expect(
              (await service().resume()).disposition,
              BackupCommitDisposition.undetermined,
            );
            expect(
              await files.keys.storage.read(key: PairKeyStore.historyKey),
              marker,
            );
            expect(await files.readManifest(), null);
          },
        );
      }
      test(
        'missing history after prior activation cannot use first-activation marker repair',
        () async {
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          await recovery.activate(candidate);
          await files.manifest.delete();
          await files.keys.removeHistory();
          process = next;
          expect(
            (await service().resume()).disposition,
            BackupCommitDisposition.undetermined,
          );
          expect(await files.keys.hasHistory(), false);
          expect(await files.readManifest(), null);
        },
      );
      test(
        'nonlegacy original cannot recreate missing history during explicit resume',
        () async {
          final a = await ready();
          await files.database(a.target).writeAsString('damaged');
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          fault = (step) async {
            if (step == 'manifest.written') throw StateError('failed');
          };
          await recovery.activate(candidate);
          fault = null;
          await files.manifest.delete();
          await files.keys.removeHistory();
          process = '10000000-0000-4000-8000-000000000003';
          expect(
            (await service().resume()).disposition,
            BackupCommitDisposition.undetermined,
          );
          expect(await files.keys.hasHistory(), false);
          expect(await files.readManifest(), null);
          expect(await files.database(a.target).exists(), true);
        },
      );
      test(
        'duplicate explicit first-marker resume owns one outstanding storage Future',
        () async {
          final storage = _HistoryFault();
          files = PairFiles(
            directory,
            PairKeyStore(storage: storage),
            protect: (_) async {},
          );
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          storage.mode = 'before';
          await recovery.activate(candidate);
          storage.mode = '';
          process = next;
          final entered = Completer<void>();
          final unblock = Completer<void>();
          storage.beforeHistoryWrite = () async {
            entered.complete();
            await unblock.future;
          };
          final first = recovery.resume();
          await entered.future;
          final second = recovery.resume();
          expect(identical(first, second), true);
          expect(storage.writes, 2);
          expect(await files.readManifest(), null);
          expect(gate.isRecoveryPending, true);
          unblock.complete();
          expect((await first).followUpPending, false);
          await second;
        },
      );
      test(
        'readable legacy with rejectLegacy false is preserved and requires normal A09 confirmation',
        () async {
          final key = await InstallationKeyStore().getOrCreate();
          await files.database(legacy).writeAsBytes([]);
          final hex = key
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final db = AppDatabase.forTesting(
            NativeDatabase(
              files.database(legacy),
              setup: (raw) {
                raw.execute('PRAGMA key = "x\'$hex\'"');
              },
            ),
          );
          await db.userDao.putUser(
            const UserEntity(
              id: 'local-profile',
              spareTime: Duration.zero,
              note: 'normal legacy',
            ),
          );
          expect(
            (await db.select(db.users).getSingle()).rejectLegacyDelivery,
            false,
          );
          await db.close();
          final original = await files.evidence(legacy);
          expect(await originalPairReadable(files, legacy), true);
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          await expectLater(
            recovery.activate(candidate),
            throwsA(isA<RecoveryOriginalAvailable>()),
          );
          await candidate.dispose();
          expect(await files.evidence(legacy), original);
          expect(await files.readManifest(), null);
        },
      );
      for (final damage in ['invalidflags', 'foreign']) {
        test(
          'ready $damage can finish a second complete encrypted recovery',
          () async {
            final a = await ready();
            final db = await openEncryptedPair(files, a.target);
            if (damage == 'invalidflags') {
              await db.customStatement(
                'UPDATE users SET reject_legacy_delivery = 0',
              );
            }
            if (damage == 'foreign') {
              await db.customStatement('PRAGMA foreign_keys=OFF');
              await db.customStatement(
                'CREATE TABLE broken_relation (id INTEGER REFERENCES users(id))',
              );
              await db.customStatement(
                "INSERT INTO broken_relation VALUES ('absent')",
              );
            }
            await db.close();
            await expectLater(
              service().prepareStartup(),
              throwsA(isA<RestoreStoreUnavailable>()),
            );
            expect(await originalPairReadable(files, a.target), false);
            final original = await files.evidence(a.target);
            final recovery = service();
            final candidate = await recovery.previewBytes(backup, password);
            final applied = await recovery.activate(candidate);
            expect(applied.disposition, BackupCommitDisposition.committed);
            expect(await files.evidence(a.target), original);
            process = '10000000-0000-4000-8000-000000000003';
            await service().prepareStartup();
            expect(await files.selected(), candidate.record.target);
            expect(await files.database(a.target).exists(), false);
            expect(await files.keys.raw(a.target), null);
          },
        );
      }
      for (final unresolved in [false, true]) {
        testWidgets(
          'actual service startup result routes unresolved=$unresolved to the correct pre-DI actions',
          (tester) async {
            tester.binding.platformDispatcher.localesTestValue = const [
              Locale('en'),
            ];
            addTearDown(
              tester.binding.platformDispatcher.clearLocalesTestValue,
            );
            await tester.runAsync(() async {
              if (unresolved) {
                final recovery = service();
                final candidate = await recovery.previewBytes(backup, password);
                fault = (step) async {
                  if (step == 'manifest.written') {
                    throw StateError('interrupted');
                  }
                };
                await recovery.activate(candidate);
                fault = null;
                process = next;
              } else {
                final state = await ready();
                await files
                    .database(state.target)
                    .writeAsString(
                      'new corruption after prior complete recovery',
                    );
              }
            });
            final failure = await tester.runAsync<Object?>(() async {
              try {
                await service().prepareStartup();
                return null;
              } catch (cause) {
                return cause;
              }
            });
            expect(
              failure,
              unresolved
                  ? isA<PairRecoveryRequired>()
                  : isA<RestoreStoreUnavailable>(),
            );
            var normalApp = 0;
            await tester.pumpWidget(
              LocalStartupGate(
                // Pass the real service outcome across the widget fake clock;
                // no substitute service failure or fabricated receipt is used.
                prepare: () async => throw failure!,
                recovery: () async => service(),
                ready: () {
                  normalApp++;
                  return const SizedBox();
                },
                beginReset: () async => const LocalResetResult(
                  intentRecorded: false,
                  completed: {},
                ),
                retryReset: () async => const LocalResetResult(
                  intentRecorded: false,
                  completed: {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(normalApp, 0);
            if (unresolved) {
              expect(find.text('Continue recovery'), findsOneWidget);
              expect(find.text('Choose backup file'), findsNothing);
              expect(find.text('Delete all local data'), findsNothing);
            } else {
              expect(find.text('Restore an OnTime Backup'), findsOneWidget);
              await tester.tap(find.text('Restore an OnTime Backup'));
              await tester.pumpAndSettle();
              expect(find.text('Choose backup file'), findsOneWidget);
            }
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
      for (final suffix in ['-wal', '-shm', '-journal']) {
        test(
          'ready target $suffix symlink refuses open and preserves external sentinel',
          () async {
            final state = await ready();
            final repairsBefore = repairs;
            final outside = await Directory.systemTemp.createTemp(
              'd02-sidecar-outside-',
            );
            addTearDown(() => outside.delete(recursive: true));
            final sentinel = File('${outside.path}/sentinel');
            await sentinel.writeAsString('outside encrypted sentinel');
            final link = Link('${files.database(state.target).path}$suffix');
            await link.create(sentinel.path);
            final original = await files.database(state.target).readAsBytes();
            await expectLater(
              openEncryptedPair(files, state.target),
              throwsA(isA<PairAuthorityUnavailable>()),
            );
            await expectLater(
              service().prepareStartup(),
              throwsA(isA<RestoreStoreUnavailable>()),
            );
            expect(await sentinel.readAsString(), 'outside encrypted sentinel');
            expect(await link.target(), sentinel.path);
            expect(await files.database(state.target).readAsBytes(), original);
            expect(repairs, repairsBefore);
          },
        );
      }
      test(
        'normal A09 restore rotates runtime inside ready pair without rewriting manifest or key',
        () async {
          final state = await ready();
          final manifest = await files.manifest.readAsBytes();
          final key = await files.keys.raw(state.target);
          final db = await openEncryptedPair(files, state.target);
          final normal = BackupService(
            db,
            _Metadata(),
            NoopAlarmCleanup(),
            crypto: crypto,
            operationGate: gate,
            stagingFactory: memoryRestoreStaging,
            ingestionFactory: memoryBackupIngestion,
            processingOwner: testBackupProcessingOwner(),
            runtimeIdentity: RestoreRuntimeIdentity(),
            cleanupPlatform: () async {},
          );
          final candidate = await normal.previewEncryptedBackup(
            backup,
            password,
          );
          await normal.applyRestore(candidate);
          await candidate.dispose();
          expect(
            (await db.select(db.users).getSingle()).storeIncarnation,
            isNot(state.runtimeIdentity),
          );
          await db.close();
          await service().prepareStartup();
          expect(await files.manifest.readAsBytes(), manifest);
          expect(await files.keys.raw(state.target), key);
          expect(gate.isAvailable, true);
        },
      );
      for (final damage in [
        'missing',
        'zero',
        'keymissing',
        'invalidflags',
        'foreign',
        'futureSchema',
      ]) {
        test(
          'ready $damage is preserved as current-store-unavailable, permits new recovery and never repairs marker',
          () async {
            final state = await ready();
            final beforeRepairs = repairs;
            final file = files.database(state.target);
            if (damage == 'missing') await file.delete();
            if (damage == 'zero') await file.writeAsBytes([]);
            if (damage == 'keymissing') await files.keys.remove(state.target);
            if (damage == 'invalidflags' ||
                damage == 'foreign' ||
                damage == 'futureSchema') {
              final db = await openEncryptedPair(files, state.target);
              if (damage == 'invalidflags') {
                await db.customStatement(
                  'UPDATE users SET reject_legacy_delivery = 0',
                );
              }
              if (damage == 'foreign') {
                await db.customStatement('PRAGMA foreign_keys=OFF');
                await db.customStatement(
                  'CREATE TABLE fault_child (id INTEGER REFERENCES users(id))',
                );
                await db.customStatement(
                  "INSERT INTO fault_child VALUES ('missing-parent')",
                );
              }
              if (damage == 'futureSchema') {
                await db.customStatement('PRAGMA user_version=999');
              }
              await db.close();
            }
            final before = await files.evidence(state.target);
            await expectLater(
              service().prepareStartup(),
              throwsA(isA<RestoreStoreUnavailable>()),
            );
            expect(repairs, beforeRepairs);
            expect(gate.isRecoveryPending, false);
            expect(await files.evidence(state.target), before);
            if (damage == 'missing') expect(await file.exists(), false);
            if (damage == 'zero') expect(await file.length(), 0);
            final candidate = await service().previewBytes(backup, password);
            expect(candidate.record.original, state.target);
            await candidate.dispose();
          },
        );
      }
      test(
        'ready manifest loss is undetermined, never committed or a fresh recovery',
        () async {
          await ready();
          await files.manifest.delete();
          await expectLater(
            service().prepareStartup(),
            throwsA(
              isA<PairRecoveryRequired>().having(
                (e) => e.receipt.disposition,
                'disposition',
                BackupCommitDisposition.undetermined,
              ),
            ),
          );
          expect(gate.isRecoveryPending, true);
        },
      );
      for (final step in [
        'record.aborting.written',
        'record.aborting.renamed',
        'abort.manifestPending.removed',
        'family..removed',
        'abort.key.removed',
        'record.cancelled.written',
        'record.cancelled.renamed',
      ]) {
        test(
          'known-original abort resumes owned cleanup after $step',
          () async {
            final a = await ready();
            await files.database(a.target).writeAsString('newly damaged');
            final recovery = service();
            final candidate = await recovery.previewBytes(backup, password);
            final oldEvidence = await files.evidence(a.target);
            fault = (phase) async {
              if (phase == 'manifest.written') {
                throw StateError('publish failed');
              }
            };
            expect(
              (await recovery.activate(candidate)).disposition,
              BackupCommitDisposition.notCommitted,
            );
            fault = (phase) async {
              if (phase == step) throw StateError('abort failed');
            };
            final pending = await recovery.abort();
            expect(pending.followUpPending, true);
            expect(gate.isRecoveryPending, true);
            expect(await files.evidence(a.target), oldEvidence);
            fault = null;
            final result = await service().abort();
            expect(result.disposition, BackupCommitDisposition.notCommitted);
            expect(result.followUpPending, false);
            expect(await files.keys.raw(candidate.record.target), null);
            expect(
              await files.database(candidate.record.target).exists(),
              false,
            );
            expect(await files.readManifest(), a.target);
            await expectLater(
              service().prepareStartup(),
              throwsA(isA<RestoreStoreUnavailable>()),
            );
            final again = await service().previewBytes(backup, password);
            await again.dispose();
          },
        );
      }
      test(
        'already-applied history cannot be aborted even if manifest is replaced by original',
        () async {
          final a = await ready();
          await files.database(a.target).writeAsString('damaged');
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          await recovery.activate(candidate);
          await files.manifest.writeAsString(files.manifestBytes(a.target));
          expect(
            (await recovery.abort()).disposition,
            BackupCommitDisposition.undetermined,
          );
          expect(await files.database(candidate.record.target).exists(), true);
          expect(await files.keys.raw(candidate.record.target), isNotNull);
        },
      );
      test(
        'original identity change refuses abort and preserves candidate',
        () async {
          final a = await ready();
          await files.database(a.target).writeAsString('damaged');
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          fault = (phase) async {
            if (phase == 'manifest.written') throw StateError('publish failed');
          };
          await recovery.activate(candidate);
          fault = null;
          await files.database(a.target).writeAsString('changed');
          expect(
            (await recovery.abort()).disposition,
            BackupCommitDisposition.undetermined,
          );
          expect(await files.database(candidate.record.target).exists(), true);
        },
      );
      test(
        'closed damaged original is preserved through encrypted preview and cancellation',
        () async {
          final before = await files.evidence(legacy);
          final candidate = await service().previewBytes(backup, password);
          final target = candidate.record.target;
          final bytes = await files.database(target).readAsBytes();
          expect(
            utf8.decode(bytes.take(16).toList(), allowMalformed: true),
            isNot('SQLite format 3\x00'),
          );
          final db = await openEncryptedPair(files, target);
          expect(
            (await db.select(db.users).getSingle()).note,
            'restored private note',
          );
          await db.close();
          expect(await files.evidence(legacy), before);
          await candidate.dispose();
          expect(await files.database(target).exists(), false);
          expect(await files.keys.raw(target), null);
          expect(await files.evidence(legacy), before);
          expect(await files.selected(), legacy);
        },
      );
      test(
        'same process preserves retired pair; new process verifies and completes cleanup',
        () async {
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          final target = candidate.record.target;
          final receipt = await recovery.activate(candidate);
          expect(receipt.recoveryFollowUp, RecoveryFollowUp.awaitingNewProcess);
          expect(await files.database(legacy).exists(), true);
          expect(repairs, 0);
          await expectLater(
            service().prepareStartup(),
            throwsA(isA<PairRecoveryRequired>()),
          );
          expect(await files.database(legacy).exists(), true);
          process = next;
          await service().prepareStartup();
          expect(await files.database(legacy).exists(), false);
          expect(await files.selected(), target);
          expect((await files.readRecord())!.stage, PairStage.ready);
          expect(gate.isRecoveryPending, false);
          final db = await openEncryptedPair(files, target);
          final row = await db.select(db.users).getSingle();
          expect(row.note, 'restored private note');
          expect(row.restoreCleanupPending, false);
          await db.close();
        },
      );
      test(
        'history marker interruption requires explicit new-process same-target resume',
        () async {
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          fault = (step) async {
            if (step == 'manifest.written') throw StateError('interrupted');
          };
          final receipt = await recovery.activate(candidate);
          expect(receipt.disposition, BackupCommitDisposition.undetermined);
          expect(await files.readManifest(), null);
          fault = null;
          process = next;
          await expectLater(
            service().prepareStartup(),
            throwsA(isA<PairRecoveryRequired>()),
          );
          expect(await files.readManifest(), null);
          final resumed = await service().resume();
          expect(resumed.disposition, BackupCommitDisposition.committed);
          expect(resumed.followUpPending, false);
          expect(await files.readManifest(), candidate.record.target);
        },
      );
      for (final interruption in ['manifest.renamed', 'manifest.readBack']) {
        test(
          'commit response loss at $interruption never reimports and retains original until restart',
          () async {
            final recovery = service();
            final candidate = await recovery.previewBytes(backup, password);
            final before = await files
                .database(candidate.record.target)
                .readAsBytes();
            fault = (step) async {
              if (step == interruption) throw StateError('lost response');
            };
            expect(
              (await recovery.activate(candidate)).disposition,
              BackupCommitDisposition.committed,
            );
            expect(await files.database(legacy).exists(), true);
            expect(
              await files.database(candidate.record.target).readAsBytes(),
              before,
            );
            fault = null;
            process = next;
            await service().prepareStartup();
            expect(await files.database(legacy).exists(), false);
          },
        );
      }
      test(
        'manifest lost after selection only republishes same target after explicit new-process resume',
        () async {
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          await recovery.activate(candidate);
          await files.manifest.delete();
          process = next;
          await expectLater(
            service().prepareStartup(),
            throwsA(isA<PairRecoveryRequired>()),
          );
          expect(await files.readManifest(), null);
          expect((await service().resume()).followUpPending, false);
          expect(await files.readManifest(), candidate.record.target);
        },
      );
      test(
        'missing manifest with a later conflicting publication is never overwritten',
        () async {
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          await recovery.activate(candidate);
          await files.manifest.delete();
          process = next;
          final other = StorePair.candidate(
            '99999999-0000-4000-8000-000000000001',
          );
          final pending = File('${files.manifest.path}.pending');
          await pending.writeAsString(files.manifestBytes(other));
          expect(
            (await service().resume()).disposition,
            BackupCommitDisposition.undetermined,
          );
          expect(await files.readManifest(), null);
          expect(await pending.readAsString(), files.manifestBytes(other));
          expect(await files.database(legacy).exists(), true);
        },
      );
      test(
        'same-process service recreation and unknown native identity never count as restart',
        () async {
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          await recovery.activate(candidate);
          expect(
            (await service().resume()).recoveryFollowUp,
            RecoveryFollowUp.awaitingNewProcess,
          );
          final unknown = RecoveryRestoreService(
            files,
            gate: gate,
            owner: owner,
            processIdentity: () async =>
                throw StateError('channel unavailable'),
            cleanupPlatform: () async {},
            repairCutover: () async {
              repairs++;
            },
          );
          expect((await unknown.resume()).followUpPending, true);
          expect(repairs, 0);
          expect(await files.database(legacy).exists(), true);
        },
      );
      test(
        'duplicate activation owns one real Future across delayed publication',
        () async {
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          final entered = Completer<void>();
          final unblock = Completer<void>();
          var writes = 0;
          fault = (step) async {
            if (step == 'manifest.written') {
              writes++;
              entered.complete();
              await unblock.future;
            }
          };
          final first = recovery.activate(candidate);
          await entered.future;
          final second = recovery.activate(candidate);
          expect(identical(first, second), true);
          expect(writes, 1);
          expect(gate.isRecoveryPending, true);
          unblock.complete();
          await first;
          await second;
        },
      );
      test(
        'DB cleanup commit followed by record failure keeps writes gated through retry',
        () async {
          final recovery = service();
          final candidate = await recovery.previewBytes(backup, password);
          await recovery.activate(candidate);
          process = next;
          fault = (step) async {
            if (step == 'record.verified.written') {
              throw StateError('interrupted');
            }
          };
          final pending = await service().resume();
          expect(pending.followUpPending, true);
          final db = await openEncryptedPair(files, candidate.record.target);
          expect(
            (await db.select(db.users).getSingle()).restoreCleanupPending,
            false,
          );
          await db.close();
          expect(gate.isRecoveryPending, true);
          expect(gate.captureWrite, throwsA(isA<LocalDataUnavailable>()));
          expect(await files.database(legacy).exists(), true);
          final blocked = Completer<void>();
          final entered = Completer<void>();
          fault = (step) async {
            if (step == 'record.verified.written') {
              entered.complete();
              await blocked.future;
            }
          };
          final retry = service().resume();
          await entered.future;
          expect(gate.isRecoveryPending, true);
          expect(gate.captureWrite, throwsA(isA<LocalDataUnavailable>()));
          blocked.complete();
          expect((await retry).followUpPending, false);
          expect(gate.isAvailable, true);
        },
      );
    },
    skip: library == null
        ? 'Needs ONTIME_TEST_SQLCIPHER_LIBRARY; plain SQLite is not cipher proof.'
        : false,
  );
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: 'test', buildNumber: '1');
}

class _HistoryFault extends FlutterSecureStorage {
  String mode = '';
  int writes = 0;
  bool wrote = false;
  Future<void> Function()? beforeHistoryWrite;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == PairKeyStore.historyKey && mode == 'readBack' && wrote) {
      throw StateError('unreadable');
    }
    return super.read(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == PairKeyStore.historyKey) {
      writes++;
      await beforeHistoryWrite?.call();
      if (mode == 'before') throw StateError('unavailable');
    }
    await super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
    if (key == PairKeyStore.historyKey) {
      wrote = true;
      if (mode == 'after') throw StateError('lost response');
    }
  }
}
