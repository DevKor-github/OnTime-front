// T03 F09 contract — actual outer COMMIT response-loss acceptance.
// Actual host SQLite + actual BackupService/sodium;
// memory staging, SharedPreferences and OS cleanup are explicit test ports.
// It does not prove SQLCipher, mobile secure storage, process death or power loss.
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/data/adapters/local_data_workflow_adapters.dart';
import 'package:on_time_front/data/repositories/user_repository_impl.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/ports/local_data_ports.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/restore_staging_fixture.dart';
import '../../helpers/sodium_test_loader.dart';

enum _Cut { beforeCommit, afterCommit }

// Marks only the real getUser call; repository watch queries are outside it.
final _identityReadZone = Object();

// Drift 2.31.0 exposes this public interceptor hook. The restore pending-marker
// UPDATE occurs after nested delete/copy transactions, so arming at this write
// avoids confusing RELEASE SAVEPOINT with the outer durable COMMIT.
final class _RestoreCommitResponse extends QueryInterceptor {
  _Cut? cut;
  final _outerTransactions = Set<TransactionExecutor>.identity();
  TransactionExecutor? _restoreTransaction;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final transaction = parent.beginTransaction();
    if (parent is! TransactionExecutor) _outerTransactions.add(transaction);
    return transaction;
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    try {
      await inner.rollback();
    } finally {
      _outerTransactions.remove(inner);
    }
  }

  int markerHits = 0;
  int injected = 0;
  int completedRestoreSends = 0;
  bool failReadbackAfterLoss = false;
  bool blockAppReads = false;
  int failedAppReads = 0;
  int identityReadSelects = 0;
  final identityFetched = Completer<void>();
  final releaseIdentity = Completer<void>();
  Map<String, Object?>? fetchedIdentity;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (blockAppReads) {
      failedAppReads++;
      throw StateError('Synthetic postcommit app readback unavailable');
    }
    final identityCall = Zone.current[_identityReadZone] == true;
    final selectedRead = identityCall ? ++identityReadSelects : 0;
    final rows = await executor.runSelect(statement, args);
    if (selectedRead == 2) {
      // getUserById is read 1; RestoreRuntimeIdentity.load is read 2.
      // Only the already fetched result is delayed. No transaction/DB lock is
      // held, and the actual active DB remains available for restore.
      expect(executor, isNot(isA<TransactionExecutor>()));
      expect(statement, contains('users'));
      expect(args, contains('local-profile'));
      fetchedIdentity = Map<String, Object?>.from(rows.single);
      identityFetched.complete();
      await releaseIdentity.future;
    }
    return rows;
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final changed = await executor.runUpdate(statement, args);
    if (cut != null && statement.contains('restore_cleanup_pending')) {
      // Public executor identity must identify the outer transaction, not a
      // nested savepoint. Fail the fixture before classifying any product bug.
      expect(executor, isA<TransactionExecutor>());
      expect(_outerTransactions.contains(executor), true);
      markerHits++;
      _restoreTransaction = executor as TransactionExecutor;
    }
    return changed;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (!identical(_restoreTransaction, inner)) {
      try {
        await inner.send();
      } finally {
        _outerTransactions.remove(inner);
      }
      return;
    }
    expect(_outerTransactions.contains(inner), true);
    _restoreTransaction = null;
    final current = cut!;
    cut = null; // One shot; cleanup commits and a valid retry are unaffected.
    injected++;
    if (current == _Cut.beforeCommit) {
      throw StateError('Synthetic precommit transaction fault');
    }
    try {
      await inner.send(); // Actual successful outer SQLite COMMIT comes first.
    } finally {
      _outerTransactions.remove(inner);
    }
    completedRestoreSends++;
    blockAppReads = failReadbackAfterLoss;
    throw StateError('Synthetic response loss after actual restore commit');
  }
}

final class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}

final class _Cleanup extends NoopAlarmCleanup {
  int calls = 0;
  @override
  Future<void> forDataReplacement() async {
    calls++;
  }
}

final class _Delivery implements RestoreDeliveryPort {
  _Delivery(this.service);
  final BackupService service;
  int calls = 0;
  @override
  Future<bool> reconcile() async {
    calls++;
    // Same production cleanup entry as LocalRestoreDeliveryAdapter, but no OS
    // reconciliation success is inferred: the controlled platform port decides.
    await service.finishRestoreCleanup();
    return true;
  }
}

final class _Fixture {
  _Fixture(
    this.directory, {
    LocalDataOperationGate? gate,
    RestoreRuntimeIdentity? identity,
  }) : gate = gate ?? LocalDataOperationGate(),
       identity = identity ?? RestoreRuntimeIdentity() {
    file = File('${directory.path}/active.sqlite');
    db = AppDatabase.forTesting(
      NativeDatabase(file).interceptWith(interceptor),
    );
    service = BackupService(
      db,
      _Metadata(),
      cleanup,
      crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
      operationGate: this.gate,
      runtimeIdentity: this.identity,
      cleanupPlatform: () async {
        platformCalls++;
        if (platformFails) throw StateError('Synthetic cleanup unavailable');
      },
      ingestionFactory: memoryBackupIngestion,
      stagingFactory: memoryRestoreStaging,
      processingOwner: testBackupProcessingOwner(),
    );
    delivery = _Delivery(service);
    workflow = BackupWorkflow(LocalBackupAdapter(service), delivery);
  }

  final Directory directory;
  final interceptor = _RestoreCommitResponse();
  final LocalDataOperationGate gate;
  final RestoreRuntimeIdentity identity;
  final cleanup = _Cleanup();
  late final File file;
  late final AppDatabase db;
  late final BackupService service;
  late final _Delivery delivery;
  late final BackupWorkflow workflow;
  BackupRestoreCandidate? input;
  int backupRevision = -1;
  bool platformFails = true;
  int platformCalls = 0;
  bool _closed = false;

  Future<void> open() async {
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'F09 restored synthetic note',
      ),
    );
    backupRevision = (await db.select(db.users).getSingle()).dataRevision;
    const password = 'F09 synthetic backup password';
    final bytes = await service.createEncryptedBackup(password);
    // Two actual writes distinguish the current revision from backup+1.
    await db.userDao.completeOnboarding(
      userId: 'local-profile',
      spareTime: const Duration(minutes: 7),
      note: 'F09 active synthetic note',
      preparationChanged: false,
    );
    await db.userDao.updateSpareTime(
      'local-profile',
      const Duration(minutes: 9),
    );
    await identity.load(db);
    input = await service.previewEncryptedBackup(bytes, password);
  }

  // Independent connection, no AppDatabase mapper, service cache or transaction
  // handle. It observes only committed rows and closes before every next action.
  Map<String, Object?> row() {
    final reader = sqlite.sqlite3.open(
      file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      expect(reader.select('PRAGMA foreign_key_check'), isEmpty);
      return Map<String, Object?>.from(
        reader.select("SELECT * FROM users WHERE id='local-profile'").single,
      );
    } finally {
      reader.dispose();
    }
  }

  Future<void> closeDb() async {
    if (_closed) return;
    _closed = true;
    await db.close();
  }

  Future<void> dispose() async {
    try {
      await input?.dispose();
    } finally {
      try {
        await closeDb();
      } finally {
        if (!identical(gate, LocalDataOperationGate.shared)) {
          gate.dispose();
        }
        await directory.delete(recursive: true);
      }
    }
  }
}

Map<String, Object?> _withoutPending(Map<String, Object?> row) =>
    Map<String, Object?>.from(row)..remove('restore_cleanup_pending');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture rig;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'early_start_session_f09': 'old synthetic runtime',
      'unrelated': 'keep',
    });
    rig = _Fixture(await Directory.systemTemp.createTemp('t03-f09-'));
    addTearDown(rig.dispose);
    await rig.open();
  });

  test(
    'F09 precommit failure preserves the original file and same candidate retries once',
    () async {
      final before = rig.row();
      rig.interceptor.cut = _Cut.beforeCommit;
      final rejected = await rig.workflow.restore(rig.input!);
      expect(rig.interceptor.markerHits, 1);
      expect(rig.interceptor.injected, 1);
      expect(rig.interceptor.completedRestoreSends, 0);
      expect(rejected.disposition, BackupCommitDisposition.notCommitted);
      expect(rig.row(), before);
      expect(rig.platformCalls, 0);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'early_start_session_f09',
        ),
        'old synthetic runtime',
      );

      rig.platformFails = false;
      final retry = await rig.workflow.restore(rig.input!);
      expect(retry.disposition, BackupCommitDisposition.committed);
      expect(retry.followUpPending, false);
      final committed = rig.row();
      expect(committed['note'], 'F09 restored synthetic note');
      expect(committed['data_revision'], rig.backupRevision + 1);
      expect(
        committed['store_incarnation'],
        isNot(before['store_incarnation']),
      );
      expect(committed['restore_cleanup_pending'], 0);
      expect(rig.gate.isAvailable, true);
    },
  );

  test(
    'F09 actual commit response loss reports committed pending and only cleanup is retried',
    () async {
      final before = rig.row();
      final initial = Completer<void>();
      final restoredNote = Completer<String>();
      final subscription = rig.db.select(rig.db.users).watch().listen((rows) {
        if (!initial.isCompleted) {
          initial.complete();
        }
        if (rows.single.note == 'F09 restored synthetic note' &&
            !restoredNote.isCompleted) {
          restoredNote.complete(rows.single.note);
        }
      });
      addTearDown(subscription.cancel);
      await initial.future.timeout(const Duration(seconds: 5));
      rig.interceptor.cut = _Cut.afterCommit;
      final receipt = await rig.workflow.restore(rig.input!);
      // First establish the physical fact independently of the workflow receipt.
      final committed = rig.row();
      expect(rig.interceptor.markerHits, 1);
      expect(rig.interceptor.injected, 1);
      expect(rig.interceptor.completedRestoreSends, 1);
      expect(committed['note'], 'F09 restored synthetic note');
      expect(committed['data_revision'], rig.backupRevision + 1);
      expect(committed['data_revision'], isNot(before['data_revision']));
      expect(
        committed['store_incarnation'],
        isNot(before['store_incarnation']),
      );
      expect(committed['restore_cleanup_pending'], 1);
      expect(committed['reject_legacy_delivery'], 1);

      // Expected to expose a current product gap until authoritative postcommit
      // readback is implemented. Never relax this to notCommitted because send()
      // threw: the independent reader above already proved a committed replacement.
      expect(receipt.disposition, BackupCommitDisposition.committed);
      expect(receipt.followUpPending, true);
      expect(
        await restoredNote.future.timeout(const Duration(seconds: 5)),
        committed['note'],
        reason: 'Existing consumers must observe the confirmed replacement',
      );
      expect(receipt.generation, 1);
      expect(rig.gate.generation, 1);
      expect(rig.gate.isRecoveryPending, true);
      expect(rig.gate.isAvailable, false);
      expect(rig.identity.accepts(before['store_incarnation']), false);
      expect(rig.identity.accepts(committed['store_incarnation']), false);
      expect(rig.platformCalls, greaterThan(0)); // Explicit cleanup failure.
      final replacementCalls = rig.cleanup.calls;

      // Repeating the same UI intent returns its held commit receipt, no apply.
      expect(
        (await rig.workflow.restore(rig.input!)).disposition,
        BackupCommitDisposition.committed,
      );
      expect(rig.cleanup.calls, replacementCalls);
      expect(rig.row(), committed);

      rig.platformFails = false;
      final recovered = await rig.workflow.retryFollowUp(receipt);
      final after = rig.row();
      expect(recovered.disposition, BackupCommitDisposition.committed);
      expect(recovered.followUpPending, false);
      expect(_withoutPending(after), _withoutPending(committed));
      expect(after['restore_cleanup_pending'], 0);
      expect(rig.cleanup.calls, replacementCalls);
      expect(rig.gate.generation, 1);
      expect(rig.gate.isAvailable, true);
      expect(rig.identity.accepts(before['store_incarnation']), false);
      expect(rig.identity.accepts(after['store_incarnation']), true);
      expect((await SharedPreferences.getInstance()).getKeys(), {'unrelated'});

      await expectLater(
        rig.service.applyRestoreWithReceipt(rig.input!),
        throwsA(
          isA<DataOperationException>().having(
            (error) => error.failure,
            'consumed candidate',
            DataOperationFailure.stalePreview,
          ),
        ),
      );
      expect(rig.row(), after);
      expect(rig.gate.generation, 1);
    },
  );

  test(
    'F09 cold file reopen recovers the committed marker without a second import',
    () async {
      final before = rig.row();
      rig.interceptor.cut = _Cut.afterCommit;
      await rig.workflow.restore(rig.input!);
      final committed = rig.row();
      expect(rig.interceptor.completedRestoreSends, 1);
      expect(
        committed['store_incarnation'],
        isNot(before['store_incarnation']),
      );
      expect(committed['restore_cleanup_pending'], 1);
      expect(committed['data_revision'], rig.backupRevision + 1);
      await rig.closeDb();

      final cold = AppDatabase.forTesting(NativeDatabase(rig.file));
      final gate = LocalDataOperationGate();
      final identity = RestoreRuntimeIdentity();
      var calls = 0;
      try {
        await expectLater(
          identity.prepareStartup(
            cold,
            gate,
            cleanupPlatform: () async {
              calls++;
              throw StateError('Synthetic cleanup still unavailable');
            },
          ),
          throwsA(isA<RestoreRecoveryRequired>()),
        );
        expect(rig.row(), committed);
        expect(gate.isRecoveryPending, true);
        expect(identity.accepts(before['store_incarnation']), false);
        expect(identity.accepts(committed['store_incarnation']), false);
        await identity.prepareStartup(
          cold,
          gate,
          cleanupPlatform: () async {
            calls++;
          },
        );
        final after = rig.row();
        expect(_withoutPending(after), _withoutPending(committed));
        expect(after['restore_cleanup_pending'], 0);
        expect(calls, 2);
        expect(
          gate.generation,
          0,
        ); // Fresh owner did not perform another restore.
        expect(gate.isAvailable, true);
        expect(identity.accepts(after['store_incarnation']), true);
        expect(rig.cleanup.calls, 1);
      } finally {
        await cold.close();
        gate.dispose();
      }
    },
  );

  test(
    'F09 unavailable app readback stays undetermined until fresh startup authority',
    () async {
      final before = rig.row();
      rig.interceptor
        ..failReadbackAfterLoss = true
        ..cut = _Cut.afterCommit;
      try {
        final receipt = await rig.workflow.restore(rig.input!);
        // This reader deliberately bypasses the failed app connection. It proves
        // the fixture's real COMMIT, but gives no authority to the running app.
        final committed = rig.row();
        expect(rig.interceptor.completedRestoreSends, 1);
        expect(
          committed['store_incarnation'],
          isNot(before['store_incarnation']),
        );
        expect(committed['note'], 'F09 restored synthetic note');
        expect(committed['restore_cleanup_pending'], 1);
        expect(committed['data_revision'], rig.backupRevision + 1);
        expect(
          rig.interceptor.failedAppReads,
          greaterThan(0),
          reason: 'The app must actually attempt authoritative readback',
        );
        expect(receipt.disposition, BackupCommitDisposition.undetermined);
        expect(rig.gate.isRecoveryPending, true);
        expect(rig.gate.isAvailable, false);
        expect(rig.gate.captureWrite, throwsA(isA<LocalDataUnavailable>()));
        expect(rig.identity.accepts(before['store_incarnation']), false);
        expect(rig.identity.accepts(committed['store_incarnation']), false);
        expect(rig.delivery.calls, 0);
        expect(rig.platformCalls, 0);
        final generation = rig.gate.generation;
        final replacements = rig.cleanup.calls;
        final sends = rig.interceptor.completedRestoreSends;

        final repeated = await rig.workflow.restore(rig.input!);
        expect(repeated.disposition, BackupCommitDisposition.undetermined);
        final noPromotion = await rig.workflow.retryFollowUp(receipt);
        expect(noPromotion.disposition, BackupCommitDisposition.undetermined);
        expect(rig.cleanup.calls, replacements);
        expect(rig.interceptor.completedRestoreSends, sends);
        expect(rig.gate.generation, generation);
        expect(rig.delivery.calls, 0);
        expect(rig.platformCalls, 0);
        expect(rig.row(), committed);

        // Losing the response did not remove the durable recovery marker. A new
        // startup owner can resolve it after opening the file independently.
        rig.interceptor.blockAppReads = false;
        await rig.closeDb();
        final cold = AppDatabase.forTesting(NativeDatabase(rig.file));
        final gate = LocalDataOperationGate();
        final identity = RestoreRuntimeIdentity();
        var platform = 0;
        try {
          await identity.prepareStartup(
            cold,
            gate,
            cleanupPlatform: () async {
              platform++;
            },
          );
          final recovered = rig.row();
          expect(_withoutPending(recovered), _withoutPending(committed));
          expect(recovered['restore_cleanup_pending'], 0);
          expect(gate.isAvailable, true);
          expect(gate.generation, 0);
          expect(identity.accepts(before['store_incarnation']), false);
          expect(identity.accepts(recovered['store_incarnation']), true);
          expect(platform, 1);
          expect(rig.cleanup.calls, replacements);
        } finally {
          await cold.close();
          gate.dispose();
        }
      } finally {
        // Assertions may fail before reopen. Never let injected SELECT failure
        // obscure teardown or keep a candidate/database owner hanging.
        rig.interceptor.blockAppReads = false;
        rig.interceptor.failReadbackAfterLoss = false;
      }
    },
  );

  test(
    'F09 stale getUser identity load cannot release an unknown restore hold',
    () async {
      // The four existing cases retain their isolated fixtures. This case uses
      // the actual shared objects required by UserRepositoryImpl.getUser.
      final gate = LocalDataOperationGate.shared;
      final identity = RestoreRuntimeIdentity.shared;
      expect(gate.isAvailable, true);
      final previousIncarnation = identity.storeIncarnation;
      final previousRejectLegacy = identity.rejectLegacy;
      final previousPending = identity.pending;
      final previousRecoveryPending = gate.isRecoveryPending;
      final race = _Fixture(
        await Directory.systemTemp.createTemp('t03-f09-identity-race-'),
        gate: gate,
        identity: identity,
      );
      UserRepositoryImpl? repository;
      Future<Object?>? oldGetUser;
      try {
        await race.open();
        final before = race.row();
        final generation = gate.generation;
        expect(identity.accepts(before['store_incarnation']), true);
        repository = UserRepositoryImpl(race.db);
        // Finish the real repository's initial watch before marking one call.
        await repository.userStream
            .firstWhere(
              (user) => user.valueOrNull?.note == 'F09 active synthetic note',
            )
            .timeout(const Duration(seconds: 5));
        final userRepository = repository;
        oldGetUser = runZoned(
          () => userRepository.getUser(),
          zoneValues: {_identityReadZone: true},
        ).then<Object?>((value) => value, onError: (Object error) => error);
        await race.interceptor.identityFetched.future.timeout(
          const Duration(seconds: 5),
        );
        expect(race.interceptor.identityReadSelects, 2);
        expect(
          race.interceptor.fetchedIdentity!['store_incarnation'],
          before['store_incarnation'],
        );
        expect(race.interceptor.fetchedIdentity!['restore_cleanup_pending'], 0);

        race.interceptor
          ..failReadbackAfterLoss = true
          ..cut = _Cut.afterCommit;
        final receipt = await race.workflow.restore(race.input!);
        // Raw independent SQLite observation proves this is a committed
        // replacement, even though this app connection cannot classify it.
        final committed = race.row();
        expect(race.interceptor.completedRestoreSends, 1);
        expect(race.interceptor.failedAppReads, greaterThan(0));
        expect(committed['note'], 'F09 restored synthetic note');
        expect(committed['data_revision'], race.backupRevision + 1);
        expect(
          committed['store_incarnation'],
          isNot(before['store_incarnation']),
        );
        expect(committed['restore_cleanup_pending'], 1);
        expect(receipt.disposition, BackupCommitDisposition.undetermined);
        expect(gate.generation, generation + 1);
        expect(gate.isRecoveryPending, true);
        expect(identity.pending, true);
        expect(identity.accepts(before['store_incarnation']), false);
        expect(identity.accepts(committed['store_incarnation']), false);

        // Return the pre-restore row while postcommit app reads remain blocked.
        // getUser's final gate check must reject its caller, but that rejection
        // alone must not conceal a stale publication into the shared identity.
        race.interceptor.releaseIdentity.complete();
        final oldResult = await oldGetUser.timeout(const Duration(seconds: 5));
        expect(oldResult, isA<LocalDataUnavailable>());
        expect(gate.isRecoveryPending, true);
        expect(gate.isAvailable, false);
        expect(gate.captureWrite, throwsA(isA<LocalDataUnavailable>()));
        expect(
          identity.accepts(before['store_incarnation']),
          false,
          reason: 'A rejected stale caller cannot reopen old runtime authority',
        );
        expect(identity.accepts(committed['store_incarnation']), false);
        expect(identity.pending, true);
        expect(race.row(), committed);
        expect(race.delivery.calls, 0);
        expect(race.platformCalls, 0);
        expect(
          (await race.workflow.restore(race.input!)).disposition,
          BackupCommitDisposition.undetermined,
        );
        expect(
          (await race.workflow.retryFollowUp(receipt)).disposition,
          BackupCommitDisposition.undetermined,
        );
        expect(race.cleanup.calls, 1);
        expect(race.interceptor.completedRestoreSends, 1);
        expect(race.row(), committed);
      } finally {
        race.interceptor
          ..blockAppReads = false
          ..failReadbackAfterLoss = false;
        if (!race.interceptor.releaseIdentity.isCompleted) {
          race.interceptor.releaseIdentity.complete();
        }
        // Remove listeners before restoring shared test state. Never dispose
        // the shared gate or rewind its generation for the next test.
        try {
          if (oldGetUser != null) {
            await oldGetUser.timeout(const Duration(seconds: 5));
          }
        } finally {
          try {
            await repository?.dispose();
          } finally {
            try {
              await race.dispose();
            } finally {
              identity
                ..storeIncarnation = previousIncarnation
                ..rejectLegacy = previousRejectLegacy
                ..pending = previousPending;
              gate.setRecoveryPending(previousRecoveryPending);
            }
          }
        }
      }
    },
  );
}
