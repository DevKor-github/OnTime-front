import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/ports/backup_time_review_port.dart';
import 'package:on_time_front/domain/ports/recovery_preclaim_cleanup_port.dart';
import 'package:drift/drift.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/ports/backup_file_import_port.dart';
import 'package:on_time_front/core/backup/backup_file_import_port.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:uuid/uuid.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_delivery_cleanup.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/ports/recovery_restore_port.dart';
import 'encrypted_pair_database.dart';
import 'native_process_identity.dart';
import 'pair_files.dart';
import 'store_pair.dart';

final class PairRecoveryRequired implements Exception {
  const PairRecoveryRequired(this.receipt);
  final BackupRestoreReceipt receipt;
}

final class RecoveryCandidate implements BackupRestoreInput {
  RecoveryCandidate(
    this.record,
    this.preview,
    this._release,
    this.lease,
    this.releaseProvisional,
    this._impacts,
    this.checkTimeAuthority,
  );
  final void Function() checkTimeAuthority;
  final PairRecord record;
  final BackupProcessingLease lease;
  final Future<void> Function() releaseProvisional;
  final Future<BackupTimeZoneImpactPage> Function({String? cursor}) _impacts;
  @override
  Future<BackupTimeZoneImpactPage> timeZoneImpacts({String? cursor}) =>
      _impacts(cursor: cursor);
  @override
  final BackupRestorePreview preview;
  final Future<void> Function() _release;
  bool claimed = false;
  @override
  Future<void> dispose() async {
    if (!claimed) await _release();
  }
}

/// Pre-DI only. The existing data gate and alarm owner serialize every mutable
/// boundary. The single flight lives beyond a disposed screen or a wait notice.
final class RecoveryRestoreService
    implements
        RecoveryRestorePort,
        BackupTimeReviewPort,
        RecoveryPreclaimCleanupPort {
  RecoveryRestoreService(
    this.files, {
    BackupCrypto? crypto,
    DateTime Function()? now,
    BackupFileImportPort? importPort,
    BackupProcessingOwner? processingOwner,
    Future<BackupIngestionStore> Function(BackupBudget)? ingestionFactory,
    LocalDataOperationGate? gate,
    AlarmOperationCoordinator? owner,
    Future<String> Function()? processIdentity,
    Future<void> Function()? cleanupPlatform,
    required this.repairCutover,
    Future<AppDatabase> Function(StorePair)? openPair,
    Future<AppDatabase> Function(StorePair)? createPair,
    Future<AppDatabase> Function(StorePair)? openStartupPair,
  }) : _now = now ?? DateTime.now,
       crypto = crypto ?? BackupCrypto(),
       importPort = importPort ?? const NativeBackupFileImportPort(),
       processingOwner = processingOwner ?? BackupProcessingOwner.shared,
       ingestionFactory = ingestionFactory ?? BackupIngestionStore.create,
       gate = gate ?? LocalDataOperationGate.shared,
       owner = owner ?? AlarmOperationCoordinator.shared,
       processIdentity = processIdentity ?? readNativeProcessIdentity,
       _cleanupPlatform = cleanupPlatform,
       openPair = openPair ?? ((pair) => openEncryptedPair(files, pair)),
       openStartupPair =
           openStartupPair ??
           openPair ??
           ((pair) => openEncryptedPair(files, pair, startupMigration: true)),
       createPair =
           createPair ??
           ((pair) => openEncryptedPair(files, pair, creating: true));
  final DateTime Function() _now;
  final PairFiles files;
  final BackupCrypto crypto;
  final BackupFileImportPort importPort;
  final BackupProcessingOwner processingOwner;
  final Future<BackupIngestionStore> Function(BackupBudget) ingestionFactory;
  final LocalDataOperationGate gate;
  final AlarmOperationCoordinator owner;
  final Future<String> Function() processIdentity;
  final Future<void> Function() repairCutover;
  final Future<void> Function()? _cleanupPlatform;
  final Future<AppDatabase> Function(StorePair) openPair;
  final Future<AppDatabase> Function(StorePair) createPair;
  final Future<AppDatabase> Function(StorePair) openStartupPair;
  Future<BackupRestoreReceipt>? _flight;
  _RecoverySourceAuthority? _preclaimCleanup;
  int? _preclaimGeneration;
  Future<void> cleanup() =>
      (_cleanupPlatform ?? () => cleanupRestoreDeliveriesUnderOwner(owner))();

  Future<void> _requireNoReset() async {
    if ((await owner.journal.read()).reset != ResetPhase.none) {
      throw const LocalDataUnavailable();
    }
  }

  Future<_RecoverySourceAuthority> _captureSource() => gate.run(
    () => owner.cleanup(() async {
      await _requireNoReset();
      if (_preclaimCleanup != null) {
        throw const DataOperationException(DataOperationFailure.busy);
      }
      final original = await files.selected();
      return _RecoverySourceAuthority(
        original,
        await files.evidence(original),
        await processIdentity(),
        gate.generation,
      );
    }),
  );

  Future<void> _checkSource(
    _RecoverySourceAuthority source, {
    bool checkGeneration = true,
  }) async {
    if ((checkGeneration && source.generation != gate.generation) ||
        await files.selected() != source.original ||
        await processIdentity() != source.process ||
        await files.evidence(source.original) != source.evidence) {
      throw const DataOperationException(DataOperationFailure.stalePreview);
    }
  }

  @override
  Future<BackupRestoreSelection?> selectForRestore(String password) async {
    final lease = processingOwner.acquire()..beginOperation();
    BackupImportSource? source;
    try {
      final authority = await _captureSource();
      source = await importPort.select(lease: lease);
      if (source == null) {
        lease.release();
        return null;
      }
      return await _reviewStream(source.openRead(), password, lease, authority);
    } catch (original) {
      try {
        await source?.close();
      } catch (cleanup) {
        lease.retainCleanup(() async {
          await source?.close();
        });
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      if (lease.phase != BackupProcessingPhase.cleanupPending) lease.release();
      rethrow;
    } finally {
      lease.endOperation();
    }
  }

  Future<BackupRestoreSelection> reviewBytes(
    Uint8List bytes,
    String password,
  ) async {
    final lease = processingOwner.acquire()..beginOperation();
    try {
      final authority = await _captureSource();
      return await _reviewStream(
        Stream.value(bytes),
        password,
        lease,
        authority,
      );
    } catch (_) {
      if (lease.phase != BackupProcessingPhase.cleanupPending) lease.release();
      rethrow;
    } finally {
      lease.endOperation();
    }
  }

  Future<BackupRestoreSelection> _reviewStream(
    Stream<List<int>> bytes,
    String password,
    BackupProcessingLease lease,
    _RecoverySourceAuthority authority,
  ) => BackupAuthenticatedTimeReview.decrypt(
    ciphertext: bytes,
    password: password,
    crypto: crypto,
    budget: BackupBudget(lease: lease),
    createStore: ingestionFactory,
    now: _now,
    ready: (content) => _prepareValidated(
      content,
      lease,
      expectedSource: authority,
      releaseOnFailure: false,
    ),
  );

  @override
  Future<RecoveryCandidate?> preview(String password) async {
    final lease = processingOwner.acquire()..beginOperation();
    BackupImportSource? source;
    try {
      source = await importPort.select(lease: lease);
      if (source == null) {
        lease.release();
        return null;
      }
      return await _previewStream(source.openRead(), password, lease);
    } catch (original) {
      try {
        await source?.close();
      } catch (cleanup) {
        lease.retainCleanup(() async {
          await source?.close();
        });
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      if (lease.phase != BackupProcessingPhase.cleanupPending) lease.release();
      rethrow;
    } finally {
      lease.endOperation();
    }
  }

  Future<RecoveryCandidate> previewBytes(
    Uint8List bytes,
    String password,
  ) async {
    final lease = processingOwner.acquire()..beginOperation();
    try {
      return await _previewStream(Stream.value(bytes), password, lease);
    } catch (_) {
      if (lease.phase != BackupProcessingPhase.cleanupPending) lease.release();
      rethrow;
    } finally {
      lease.endOperation();
    }
  }

  Future<RecoveryCandidate> _previewStream(
    Stream<List<int>> bytes,
    String password,
    BackupProcessingLease lease,
  ) async {
    final authority = await _captureSource();
    final rules = TimeZoneRules.loadedIdentity;
    final content = await BackupValidatedIngestion.decrypt(
      ciphertext: bytes,
      password: password,
      crypto: crypto,
      budget: BackupBudget(lease: lease),
      createStore: ingestionFactory,
      nowUtc: _now().toUtc(),
    );
    try {
      content.establishTimeAuthority(rules);
    } catch (_) {
      try {
        await content.release();
      } catch (_) {
        lease.retainCleanup(content.release);
        rethrow;
      }
      rethrow;
    }
    return _prepareValidated(content, lease, expectedSource: authority);
  }

  Future<RecoveryCandidate> _prepareValidated(
    BackupValidatedIngestion content,
    BackupProcessingLease lease, {
    required _RecoverySourceAuthority expectedSource,
    bool releaseOnFailure = true,
  }) async {
    void checkTime() {
      if (!content.hasCurrentTimeAuthority(_now())) {
        throw const DataOperationException(DataOperationFailure.stalePreview);
      }
    }

    Future<void> releaseProvisional() async {
      try {
        await content.release();
      } catch (_) {
        lease.retainCleanup(content.release);
        rethrow;
      }
      lease.release();
    }

    try {
      return await gate.run(
        () => owner.cleanup(() async {
          await _requireNoReset();
          await _checkSource(expectedSource);
          checkTime();
          final prior = await files.readRecord();
          if (prior != null &&
              prior.stage != PairStage.ready &&
              prior.stage != PairStage.cancelled) {
            throw const DataOperationException(DataOperationFailure.busy);
          }
          final original = await files.selected();
          final origin = await processIdentity();
          final target = StorePair.candidate(const Uuid().v4());
          var record = PairRecord(
            target: target,
            original: original,
            originProcess: origin,
            stage: PairStage.reserved,
          );
          await files.writeRecord(
            record,
          ); // Reservation must precede any new key.
          AppDatabase? db;
          Future<void> cleanupCandidate() async {
            await db?.close();
            db = null;
            await _discard(record);
          }

          try {
            final evidence = await files.evidence(original);
            await files.keys.create(target);
            await files.prepareDirectories();
            await files.database(target).create(exclusive: true);
            await files.protect(files.database(target));
            final createdDb = await createPair(target);
            db = createdDb;
            await content.materialize(createdDb, pendingCleanup: true);
            await content.validateReadBack(createdDb, pendingCleanup: true);
            final row = await createdDb.select(createdDb.users).getSingle();
            final runtime = row.storeIncarnation;
            if (runtime == null ||
                !row.restoreCleanupPending ||
                !row.rejectLegacyDelivery) {
              throw const PairAuthorityUnavailable();
            }
            await createdDb
                .customSelect('PRAGMA wal_checkpoint(TRUNCATE)')
                .get();
            await createdDb.close();
            db = null;
            final reopenedDb = await openPair(target);
            db = reopenedDb;
            await content.validateReadBack(reopenedDb, pendingCleanup: true);
            await reopenedDb.close();
            db = null;
            await _checkSource(expectedSource);
            checkTime();
            if (evidence != await files.evidence(original)) {
              throw const DataOperationException(
                DataOperationFailure.stalePreview,
              );
            }
            record = record.at(
              PairStage.validated,
              evidence: evidence,
              runtime: runtime,
            );
            await files.writeRecord(record);
            await _checkSource(expectedSource);
            checkTime();
            lease.check();
            lease.update(BackupProcessingPhase.preview);
            return RecoveryCandidate(
              record,
              content.preview,
              () async {
                try {
                  await discard(target);
                  await content.release();
                } catch (error) {
                  lease.retainCleanup(() async {
                    await discard(target);
                    await content.release();
                  });
                  rethrow;
                }
                lease.release();
              },
              lease,
              releaseProvisional,
              content.timeZoneImpacts,
              checkTime,
            );
          } catch (original) {
            try {
              await cleanupCandidate();
            } catch (cleanup) {
              // Retain the DB close + existing pair authority cleanup together.
              lease.retainCleanup(
                () => gate.run(() => owner.cleanup(cleanupCandidate)),
              );
              throw BackupProcessingCleanupFailure(
                originalError: original,
                cleanupError: cleanup,
              );
            }
            rethrow;
          }
        }),
      );
    } catch (original) {
      if (!releaseOnFailure) rethrow;
      try {
        await content.release();
      } catch (cleanup) {
        lease.retainCleanup(content.release);
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }

  Future<void> discard(StorePair target) => gate.run(
    () => owner.cleanup(() async {
      final record = await files.readRecord();
      if (record == null || record.target != target || record.confirmed) return;
      await _discard(record);
    }),
  );
  Future<void> _discard(PairRecord record) async {
    final active = await files.readManifest();
    if (active == record.target || record.confirmed) {
      throw const PairAuthorityUnavailable();
    }
    await files.removeFamily(record.target);
    await files.keys.remove(record.target);
    if (record.original.isLegacy && !await files.keys.hasHistory()) {
      await files.removeRecord();
    } else {
      await files.writeRecord(record.at(PairStage.cancelled));
    }
  }

  @override
  Future<void> retryPreclaimCleanup(int generation) => gate.run(
    () => owner.cleanup(() async {
      final source = _preclaimCleanup;
      if (source == null ||
          generation != _preclaimGeneration ||
          generation != gate.generation) {
        throw const DataOperationException(DataOperationFailure.stalePreview);
      }
      await _requireNoReset();
      await _checkSource(source, checkGeneration: false);
      final record = await files.readRecord();
      if (record?.confirmed == true) throw const PairAuthorityUnavailable();
      try {
        await cleanup();
      } catch (_) {
        throw DataOperationException(
          DataOperationFailure.stalePreview,
          followUpPending: true,
          generation: generation,
        );
      }
      await _checkSource(source, checkGeneration: false);
      _preclaimCleanup = null;
      _preclaimGeneration = null;
    }),
  );

  @override
  Future<BackupRestoreReceipt> activate(BackupRestoreInput input) {
    if (_flight != null) return _flight!;
    if (input is! RecoveryCandidate) {
      throw const DataOperationException(DataOperationFailure.invalidBackup);
    }
    input.claimed = true;
    input.lease.beginOperation();
    input.lease.cancellationAllowed = false;
    input.lease.update(BackupProcessingPhase.applying);
    return _flight = gate
        .run(
          () => owner.cleanup(() async {
            await _requireNoReset();
            var record = await files.readRecord();
            if (record == null ||
                record.target != input.record.target ||
                record.stage != PairStage.validated ||
                record.originProcess != await processIdentity() ||
                await files.selected() != record.original ||
                record.originalEvidence !=
                    await files.evidence(record.original)) {
              input.claimed = false;
              throw const DataOperationException(
                DataOperationFailure.stalePreview,
              );
            }
            if (await originalPairReadable(files, record.original)) {
              throw const RecoveryOriginalAvailable();
            }
            if (input.preview.cutoffLiteral != null) {
              // This local installation marker describes this commit, never the
              // unknown instant of an offsetless legacy backup cutoff.
              final candidateDb = await openPair(record.target);
              try {
                final marker = _now().toUtc();
                await (candidateDb.update(
                  candidateDb.users,
                )..where((u) => u.id.equals(localProfileId))).write(
                  UsersCompanion(
                    firstDurableDataAt: Value(marker),
                    lastDurableDataAt: Value(marker),
                  ),
                );
              } finally {
                try {
                  await candidateDb.close();
                } catch (_) {
                  input.lease.retainCleanup(candidateDb.close);
                  rethrow;
                }
              }
            }
            await _verify(record, requirePending: true);
            input.checkTimeAuthority();
            final preclaim = _RecoverySourceAuthority(
              record.original,
              record.originalEvidence!,
              record.originProcess,
              gate.generation,
            );
            _preclaimCleanup = preclaim;
            _preclaimGeneration = gate.generation;
            try {
              await cleanup();
              await _requireNoReset();
              await _checkSource(preclaim);
              input.checkTimeAuthority();
              final current = await files.readRecord();
              if (current == null ||
                  current.target != record.target ||
                  current.stage != PairStage.validated) {
                throw const DataOperationException(
                  DataOperationFailure.stalePreview,
                );
              }
              input.checkTimeAuthority();
            } catch (_) {
              throw DataOperationException(
                DataOperationFailure.stalePreview,
                followUpPending: true,
                generation: gate.generation,
              );
            }
            record = record.at(PairStage.confirmed);
            // From this intent onward an uncertain write cannot reopen normal use.
            gate.setRecoveryPending(true);
            try {
              await files.writeRecord(record);
              _preclaimCleanup = null;
              _preclaimGeneration = null;
              await files.keys.markHistory();
              await files.publish(
                record.target,
                expected: record.original.isLegacy ? null : record.original,
              );
              await files.writeRecord(record.at(PairStage.activated));
              return _receipt(RecoveryFollowUp.awaitingNewProcess);
            } catch (_) {
              try {
                final durable = await files.readRecord();
                if (durable != null &&
                    durable.target == record.target &&
                    !durable.confirmed &&
                    await files.readManifest() != record.target &&
                    !await files.keys.hasHistory()) {
                  input.claimed = false;
                  gate.setRecoveryPending(false);
                  throw DataOperationException(
                    DataOperationFailure.stalePreview,
                    followUpPending: true,
                    generation: gate.generation,
                  );
                }
              } on DataOperationException {
                rethrow;
              } catch (_) {
                /* Retain uncertain ownership. */
              }
              _preclaimCleanup = null;
              _preclaimGeneration = null;
              return _observe(record);
            }
          }),
          replacesData: true,
          validateReplacement: () async {
            if (_preclaimCleanup != null) {
              throw const DataOperationException(DataOperationFailure.busy);
            }
            input.checkTimeAuthority();
          },
        )
        .whenComplete(() async {
          if (gate.isRecoveryPending) {
            try {
              await input.releaseProvisional();
            } catch (_) {
              /* Separate cleanup remains owned and retryable. */
            }
          }
          if (!gate.isRecoveryPending) input.claimed = false;
          _flight = null;
          input.lease.endOperation();
        });
  }

  BackupRestoreReceipt _receipt(RecoveryFollowUp phase) =>
      BackupRestoreReceipt.recovery(generation: gate.generation, phase: phase);
  Future<BackupRestoreReceipt> _observe(PairRecord record) async {
    try {
      final durable = await files.readRecord();
      if (durable == null || durable.target != record.target) {
        throw const PairAuthorityUnavailable();
      }
      record = durable;
      final current = await files.readManifest();
      await files.checkIntent(record);
      if (current == record.target) {
        return _receipt(RecoveryFollowUp.awaitingNewProcess);
      }
      // Once the history marker is written a missing first manifest is an
      // explicit interrupted-publication case, never implicit legacy authority.
      if (current == record.original &&
          current != null &&
          (record.stage == PairStage.confirmed ||
              record.stage == PairStage.aborting) &&
          record.originalEvidence == await files.evidence(record.original)) {
        await files.checkIntent(record, forAbort: true);
        return BackupRestoreReceipt(
          disposition: BackupCommitDisposition.notCommitted,
          generation: gate.generation,
          followUpPending: true,
        );
      }
    } catch (_) {
      /* Unknown is not false. */
    }
    return BackupRestoreReceipt.uncertain(generation: gate.generation);
  }

  Future<void> _verify(
    PairRecord record, {
    required bool requirePending,
    bool currentRuntime = false,
    StorePair? pair,
    bool startupMigration = false,
  }) async {
    final db = await (startupMigration ? openStartupPair : openPair)(
      pair ?? record.target,
    );
    try {
      final integrity = await db.customSelect('PRAGMA quick_check').getSingle();
      final foreign = await db.customSelect('PRAGMA foreign_key_check').get();
      final row = await db.select(db.users).getSingle();
      if (integrity.data.values.single != 'ok' ||
          foreign.isNotEmpty ||
          row.id != localProfileId ||
          row.storeIncarnation == null ||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch(row.storeIncarnation!) ||
          (!currentRuntime && row.storeIncarnation != record.runtimeIdentity) ||
          !row.rejectLegacyDelivery ||
          (requirePending && !row.restoreCleanupPending)) {
        throw const PairAuthorityUnavailable();
      }
    } finally {
      await db.close();
    }
  }

  @override
  Future<BackupRestoreReceipt> abort() => _flight ??= owner
      .cleanup(() async {
        await _requireNoReset();
        gate.setRecoveryPending(true);
        final record = await files.readRecord();
        if (record == null) {
          return BackupRestoreReceipt.uncertain(generation: gate.generation);
        }
        try {
          return await _abort(record);
        } catch (_) {
          return _observe(record);
        }
      })
      .whenComplete(() => _flight = null);
  Future<BackupRestoreReceipt> _abort(PairRecord record) async {
    if (record.stage == PairStage.cancelled) {
      if (await files.selected() != record.original ||
          await files.keys.raw(record.target) != null ||
          await files.exists(files.database(record.target).path)) {
        throw const PairAuthorityUnavailable();
      }
      gate.setRecoveryPending(false);
      return BackupRestoreReceipt(
        disposition: BackupCommitDisposition.notCommitted,
        generation: gate.generation,
      );
    }
    if (record.stage != PairStage.confirmed &&
        record.stage != PairStage.aborting) {
      throw const PairAuthorityUnavailable();
    }
    await files.checkIntent(record, forAbort: true);
    if (record.original.isLegacy ||
        await files.readManifest() != record.original ||
        record.originalEvidence != await files.evidence(record.original)) {
      throw const PairAuthorityUnavailable();
    }
    final aborting = record.at(PairStage.aborting);
    if (record.stage != PairStage.aborting) await files.writeRecord(aborting);
    await files.removeOwnedPublication(aborting);
    await files.removeFamily(record.target);
    await files.keys.remove(record.target);
    await files.checkpoint?.call('abort.key.removed');
    await files.writeRecord(record.at(PairStage.cancelled));
    gate.setRecoveryPending(false);
    return BackupRestoreReceipt(
      disposition: BackupCommitDisposition.notCommitted,
      generation: gate.generation,
    );
  }

  /// Startup inspects authority but never publishes a missing manifest by itself.
  Future<void> prepareStartup() async {
    try {
      await _prepareStartup();
    } on PairRecoveryRequired {
      rethrow;
    } on RestoreStoreUnavailable {
      rethrow;
    } catch (_) {
      gate.setRecoveryPending(true);
      throw PairRecoveryRequired(
        BackupRestoreReceipt.uncertain(generation: gate.generation),
      );
    }
  }

  Future<void> _prepareStartup() async {
    await _requireNoReset();
    final state = await files.readRecord();
    if (state == null) {
      await files.selected();
      return;
    }
    if (!state.confirmed && state.stage != PairStage.cancelled) {
      await owner.cleanup(() => _discard(state));
      await files.selected();
      gate.setRecoveryPending(false);
      final remaining = await files.readRecord();
      if (remaining != null) await _prepareCurrent(remaining);
      return;
    }
    if (state.stage == PairStage.ready || state.stage == PairStage.cancelled) {
      await _prepareCurrent(state);
      return;
    }
    final receipt = await resume(allowPublish: false);
    if (receipt.followUpPending || state.stage == PairStage.aborting) {
      throw PairRecoveryRequired(receipt);
    }
  }

  Future<void> _prepareCurrent(PairRecord state) => owner.cleanup(() async {
    await _requireNoReset();
    final pair = state.stage == PairStage.ready ? state.target : state.original;
    // Selection errors remain unknown authority, separate from a selected
    // completed store that has become damaged and can accept a new recovery.
    if (await files.selected() != pair) throw const PairAuthorityUnavailable();
    try {
      await _verify(
        state,
        requirePending: false,
        currentRuntime: true,
        pair: pair,
        startupMigration: true,
      );
    } catch (cause) {
      gate.setRecoveryPending(false);
      throw RestoreStoreUnavailable(cause);
    }
    gate.setRecoveryPending(true);
    try {
      final db = await openStartupPair(pair);
      try {
        await RestoreRuntimeIdentity.shared.cleanup(
          db,
          gate,
          cleanupPlatform: cleanup,
          releaseGate: false,
        );
      } finally {
        await db.close();
      }
      await _verify(
        state,
        requirePending: false,
        currentRuntime: true,
        pair: pair,
        startupMigration: true,
      );
      await repairCutover();
      gate.setRecoveryPending(false);
    } catch (_) {
      throw PairRecoveryRequired(_receipt(RecoveryFollowUp.cleanupPending));
    }
  });
  @override
  Future<BackupRestoreReceipt> resume({bool allowPublish = true}) {
    return _flight ??= owner
        .cleanup(() async {
          await _requireNoReset();
          gate.setRecoveryPending(true);
          final record = await files.readRecord();
          if (record == null) throw const PairAuthorityUnavailable();
          if (!record.confirmed) {
            if (record.stage != PairStage.cancelled) await _discard(record);
            gate.setRecoveryPending(false);
            return BackupRestoreReceipt(
              disposition: BackupCommitDisposition.notCommitted,
              generation: gate.generation,
            );
          }
          var phase = RecoveryFollowUp.verifyingPair;
          try {
            if (record.stage == PairStage.aborting) return _abort(record);
            if (record.stage == PairStage.ready) {
              if (await files.selected() != record.target) {
                throw const PairAuthorityUnavailable();
              }
              await _verify(
                record,
                requirePending: false,
                currentRuntime: true,
              );
              final db = await openPair(record.target);
              try {
                await RestoreRuntimeIdentity.shared.cleanup(
                  db,
                  gate,
                  cleanupPlatform: cleanup,
                  releaseGate: false,
                );
              } finally {
                await db.close();
              }
              await repairCutover();
              gate.setRecoveryPending(false);
              return BackupRestoreReceipt(
                disposition: BackupCommitDisposition.committed,
                generation: gate.generation,
              );
            }
            await files.checkIntent(record);
            final process = await processIdentity();
            var active = await files.readManifest();
            if (active == null &&
                allowPublish &&
                process != record.originProcess &&
                record.stage != PairStage.ready &&
                record.originalEvidence ==
                    await files.evidence(record.original)) {
              await _verify(record, requirePending: true);
              if (!await files.keys.hasHistory()) {
                if (!record.original.isLegacy ||
                    record.stage != PairStage.confirmed) {
                  throw const PairAuthorityUnavailable();
                }
                await files.checkIntent(record, firstActivation: true);
                await files.keys.markHistory();
              }
              // Explicit Q5 exception: same confirmed target and same bytes only.
              await files.publish(record.target);
              active = await files.readManifest();
            }
            if (active != record.target) return _observe(record);
            if (process == record.originProcess) {
              return _receipt(RecoveryFollowUp.awaitingNewProcess);
            }
            await _verify(record, requirePending: false);
            phase = RecoveryFollowUp.cleanupPending;
            await repairCutover();
            final db = await openPair(record.target);
            try {
              await RestoreRuntimeIdentity.shared.cleanup(
                db,
                gate,
                cleanupPlatform: cleanup,
                releaseGate: false,
              );
            } finally {
              await db.close();
            }
            // Cleanup can clear its DB pending flag before the record write fails.
            // Retry verifies the identity even when that completed stage is observed.
            await files.writeRecord(record.at(PairStage.verified));
            await files.removeFamily(record.original);
            await files.keys.remove(record.original);
            await files.writeRecord(record.at(PairStage.ready));
            gate.setRecoveryPending(false);
            return BackupRestoreReceipt(
              disposition: BackupCommitDisposition.committed,
              generation: gate.generation,
            );
          } catch (_) {
            final observed = await _observe(record);
            if (observed.disposition != BackupCommitDisposition.committed) {
              return observed;
            }
            return _receipt(phase);
          }
        })
        .whenComplete(() => _flight = null);
  }
}

final class _RecoverySourceAuthority {
  const _RecoverySourceAuthority(
    this.original,
    this.evidence,
    this.process,
    this.generation,
  );
  final StorePair original;
  final String evidence;
  final String process;
  final int generation;
}
