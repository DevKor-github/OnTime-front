import '../time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/ports/backup_file_import_port.dart';
import 'backup_file_import_port.dart';
import 'backup_ingestion_store.dart';
import 'backup_validated_ingestion.dart';
import 'backup_limits.dart';
import 'package:on_time_front/core/database/restore_delivery_cleanup.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
export 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'backup_export_snapshot.dart';
import 'backup_password.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_file_export_port.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';

class BackupRestoreCandidate implements BackupRestoreInput {
  BackupRestoreCandidate._(
    this._data,
    this.preview,
    this._generation,
    this._revision,
    this._staging,
    this._lease,
  );

  int _generation;
  final int _revision;
  bool _consumed = false;
  Future<int>? _running;

  final RestoreStaging _staging;
  @override
  Future<void> dispose() async {
    if (_running != null) await _running!.catchError((_) => -1);
    _consumed = true;
    await _releaseResources();
  }

  final BackupProcessingLease _lease;
  final BackupValidatedIngestion _data;
  Future<void> _releaseResources() async {
    if (_lease.phase == BackupProcessingPhase.cleanupPending) {
      await _lease.retryCleanup();
      return;
    }
    Future<void> cleanup() async {
      Object? original;
      try {
        await _staging.release();
      } catch (error) {
        original = error;
      }
      try {
        await _data.release();
      } catch (error) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: error,
        );
      }
      if (original != null) throw original;
    }

    try {
      await cleanup();
    } catch (error) {
      _lease.retainCleanup(cleanup);
      rethrow;
    }
    _lease.release();
  }

  @override
  final BackupRestorePreview preview;
  @override
  Future<BackupTimeZoneImpactPage> timeZoneImpacts({String? cursor}) =>
      _data.timeZoneImpacts(cursor: cursor);
}

@lazySingleton
class BackupService {
  BackupService(
    this._database,
    this._metadataProvider,
    this._cancelAllAlarms, {
    @ignoreParam BackupCrypto? crypto,
    @ignoreParam BackupFileExportPort? exportPort,
    @ignoreParam BackupFileImportPort? importPort,
    @ignoreParam BackupProcessingOwner? processingOwner,
    @ignoreParam
    Future<BackupIngestionStore> Function(BackupBudget)? ingestionFactory,
    @ignoreParam LocalDataOperationGate? operationGate,
    @ignoreParam RestoreStagingFactory? stagingFactory,
    @ignoreParam RestoreRuntimeIdentity? runtimeIdentity,
    @ignoreParam Future<void> Function()? cleanupPlatform,
    @ignoreParam DateTime Function()? now,
  }) : _crypto = crypto ?? BackupCrypto(),
       _exportPort = exportPort ?? const NativeBackupFileExportPort(),
       _importPort = importPort ?? const NativeBackupFileImportPort(),
       _processingOwner = processingOwner ?? BackupProcessingOwner.shared,
       _ingestionFactory = ingestionFactory ?? BackupIngestionStore.create,
       _operationGate = operationGate ?? LocalDataOperationGate.shared,
       _stagingFactory = stagingFactory ?? RestoreStaging.create,
       _runtimeIdentity = runtimeIdentity ?? RestoreRuntimeIdentity.shared,
       _cleanupPlatform = cleanupPlatform,
       _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Future<void> Function()? _cleanupPlatform;
  final RestoreStagingFactory _stagingFactory;
  final RestoreRuntimeIdentity _runtimeIdentity;
  final AppDatabase _database;
  final CancelAllAlarmsUseCase _cancelAllAlarms;
  final AppMetadataProvider _metadataProvider;
  final BackupCrypto _crypto;
  final BackupFileExportPort _exportPort;
  final BackupFileImportPort _importPort;
  final BackupProcessingOwner _processingOwner;
  final Future<BackupIngestionStore> Function(BackupBudget) _ingestionFactory;
  final LocalDataOperationGate _operationGate;
  final _pendingStagingCleanup = <BackupRestoreCandidate>{};
  bool _restoreCommitUndetermined = false;
  int get generation => _operationGate.generation;

  Future<BackupExportResult> exportToUserSelectedFile(String password) async {
    BackupPassword.parse(password);
    final lease = _processingOwner.acquire()..beginOperation();
    try {
      _PreparedExport? prepared;
      var saved = false;
      Object? original;
      BackupExportResult? result;
      try {
        prepared = await _prepareExport(lease);
        final receipt = await _exportPort.exportStream(
          encrypted: _encryptedExport(prepared, password),
          suggestedName:
              'OnTime-${_fileDate(prepared.snapshot.cutoff)}.ontimebackup',
          lease: lease,
        );
        saved = receipt == BackupFileExportReceipt.saved;
        if (!saved) {
          result = BackupExportResult.cancelled;
        } else if (_operationGate.generation != prepared.generation) {
          result = BackupExportResult.savedFreshnessUpdateFailed;
        } else {
          try {
            await _database.userDao.markExported(
              userId: localProfileId,
              revision: prepared.snapshot.dataRevision,
              cutoff: prepared.snapshot.cutoff,
            );
            result = BackupExportResult.saved;
          } catch (_) {
            result = BackupExportResult.savedFreshnessUpdateFailed;
          }
        }
      } catch (error) {
        original =
            error is BackupProcessingFailure ||
                error is BackupProcessingCleanupFailure
            ? error
            : const BackupFileExportFailure();
      }
      await _finishExport(prepared, lease, original: original, saved: saved);
      if (original != null) throw original;
      return result!;
    } finally {
      lease.endOperation();
    }
  }

  Future<RestoreStaging> _createOwnedStaging(
    BackupProcessingLease lease,
  ) async {
    try {
      return await _stagingFactory();
    } on RestoreStagingCleanupFailure catch (error) {
      if (error.retryCleanup != null) lease.retainCleanup(error.retryCleanup!);
      throw BackupProcessingCleanupFailure(
        originalError: error.originalError,
        cleanupError: error.cleanupError,
      );
    }
  }

  Future<_PreparedExport> _prepareExport(BackupProcessingLease lease) async {
    final budget = BackupBudget(lease: lease);
    final generation = _operationGate.generation;
    final snapshot = await _operationGate.run(() async {
      final metadata = await _metadataProvider.getMetadata();
      return BackupExportSnapshot.create(
        _database,
        cutoff: DateTime.now().toUtc(),
        sourceAppVersion: '${metadata.version}+${metadata.buildNumber}',
        sourcePlatform: _sourcePlatform(),
        budget: budget,
        stagingFactory: () => _createOwnedStaging(lease),
      );
    });
    try {
      lease.update(BackupProcessingPhase.validating);
      final digest = _ExportDigest();
      final hash = sha256.startChunkedConversion(digest);
      Stream<List<int>> counted() async* {
        await for (final chunk in snapshot.plaintext()) {
          budget.plaintext(chunk.length);
          hash.add(chunk);
          yield chunk;
        }
        hash.close();
      }

      final validated = await BackupValidatedIngestion.validateOwnedSnapshot(
        plaintext: counted(),
        budget: budget,
        createStore: _ingestionFactory,
        nowUtc: snapshot.cutoff,
      );
      try {
        await validated.release();
      } catch (error) {
        lease.retainCleanup(validated.release);
        rethrow;
      }
      return _PreparedExport(
        snapshot,
        budget,
        budget.plainBytes,
        digest.value!,
        generation,
      );
    } catch (original) {
      try {
        await snapshot.release();
      } catch (cleanup) {
        lease.retainCleanup(snapshot.release);
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }

  Stream<List<int>> _encryptedExport(
    _PreparedExport prepared,
    String password,
  ) {
    final budget = prepared.budget.bytePass();
    budget.lease?.update(BackupProcessingPhase.encrypting);
    Stream<List<int>> verifiedSecondPass() async* {
      final digest = _ExportDigest();
      final hash = sha256.startChunkedConversion(digest);
      var length = 0;
      await for (final chunk in prepared.snapshot.plaintext()) {
        length += chunk.length;
        if (length > prepared.length) BackupLimits.invalid();
        hash.add(chunk);
        yield chunk;
      }
      hash.close();
      if (length != prepared.length || digest.value != prepared.digest) {
        BackupLimits.invalid();
      }
    }

    return _crypto.encryptStream(
      plaintext: verifiedSecondPass(),
      plaintextLength: prepared.length,
      password: password,
      budget: budget,
    );
  }

  Future<void> _finishExport(
    _PreparedExport? prepared,
    BackupProcessingLease lease, {
    Object? original,
    bool saved = false,
  }) async {
    try {
      await prepared?.snapshot.release();
    } catch (cleanup) {
      lease.retainCleanup(prepared!.snapshot.release);
      if (!saved) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
    }
    if (lease.phase != BackupProcessingPhase.cleanupPending) lease.release();
  }

  /// Authenticated selection can require explicit time review. A review owns
  /// the same lease but has no active database or ready-preview authority.
  Future<BackupRestoreSelection> reviewEncryptedBackup(
    Uint8List encrypted,
    String password,
  ) async {
    final lease = _processingOwner.acquire()..beginOperation();
    try {
      return await _reviewStream(Stream.value(encrypted), password, lease);
    } catch (_) {
      if (lease.phase != BackupProcessingPhase.cleanupPending) lease.release();
      rethrow;
    } finally {
      lease.endOperation();
    }
  }

  Future<BackupRestoreSelection?> selectAndReviewRestore(
    String password,
  ) async {
    final lease = _processingOwner.acquire()..beginOperation();
    BackupImportSource? source;
    try {
      source = await _importPort.select(lease: lease);
      if (source == null) {
        lease.release();
        return null;
      }
      return await _reviewStream(source.openRead(), password, lease);
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

  Future<BackupRestoreSelection> _reviewStream(
    Stream<List<int>> encrypted,
    String password,
    BackupProcessingLease lease,
  ) async {
    final selectedGeneration = generation;
    final selectedRevision = await _currentRevision();
    if (selectedGeneration != generation) {
      throw const DataOperationException(DataOperationFailure.stalePreview);
    }
    return BackupAuthenticatedTimeReview.decrypt(
      ciphertext: encrypted,
      password: password,
      crypto: _crypto,
      budget: BackupBudget(lease: lease),
      createStore: _ingestionFactory,
      now: _now,
      ready: (data) async {
        RestoreStaging? staging;
        try {
          lease.check();
          if (!data.hasCurrentTimeAuthority(_now())) {
            throw const DataOperationException(
              DataOperationFailure.stalePreview,
            );
          }
          if (generation != selectedGeneration ||
              await _currentRevision() != selectedRevision) {
            throw const DataOperationException(
              DataOperationFailure.stalePreview,
            );
          }
          staging = await _createOwnedStaging(lease);
          lease.check();
          await data.materialize(staging.database, pendingCleanup: false);
          await data.validateReadBack(staging.database, pendingCleanup: false);
          lease.check();
          if (!data.hasCurrentTimeAuthority(_now())) {
            throw const DataOperationException(
              DataOperationFailure.stalePreview,
            );
          }
          if (generation != selectedGeneration ||
              await _currentRevision() != selectedRevision) {
            throw const DataOperationException(
              DataOperationFailure.stalePreview,
            );
          }
          lease.update(BackupProcessingPhase.preview);
          return BackupRestoreCandidate._(
            data,
            data.preview,
            selectedGeneration,
            selectedRevision,
            staging,
            lease,
          );
        } catch (original) {
          try {
            await staging?.release();
          } catch (cleanup) {
            lease.retainCleanup(() async {
              await staging?.release();
            });
            throw BackupProcessingCleanupFailure(
              originalError: original,
              cleanupError: cleanup,
            );
          }
          rethrow;
        }
      },
    );
  }

  Future<BackupRestoreCandidate?> selectAndPreviewRestore(
    String password,
  ) async {
    final lease = _processingOwner.acquire()..beginOperation();
    BackupImportSource? source;
    try {
      source = await _importPort.select(lease: lease);
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

  /// Explicit small/memory adapter, using the same authenticated bounded engine.
  Future<BackupRestoreCandidate> previewEncryptedBackup(
    Uint8List encrypted,
    String password,
  ) async {
    final lease = _processingOwner.acquire()..beginOperation();
    try {
      return await _previewStream(Stream.value(encrypted), password, lease);
    } catch (_) {
      if (lease.phase != BackupProcessingPhase.cleanupPending) lease.release();
      rethrow;
    } finally {
      lease.endOperation();
    }
  }

  Future<BackupRestoreCandidate> _previewStream(
    Stream<List<int>> encrypted,
    String password,
    BackupProcessingLease lease,
  ) async {
    final selectedRules = TimeZoneRules.loadedIdentity;
    BackupValidatedIngestion? data;
    RestoreStaging? staging;
    Future<void> cleanup() async {
      Object? original;
      try {
        await staging?.release();
      } catch (error) {
        original = error;
      }
      try {
        await data?.release();
      } catch (error) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: error,
        );
      }
      if (original != null) throw original;
    }

    try {
      data = await BackupValidatedIngestion.decrypt(
        ciphertext: encrypted,
        password: password,
        crypto: _crypto,
        budget: BackupBudget(lease: lease),
        createStore: _ingestionFactory,
        nowUtc: _now().toUtc(),
      );
      data.establishTimeAuthority(selectedRules);
      lease.update(BackupProcessingPhase.validating);
      final previewGeneration = generation;
      final revision = await _currentRevision();
      if (previewGeneration != generation ||
          !data.hasCurrentTimeAuthority(_now())) {
        throw const DataOperationException(DataOperationFailure.stalePreview);
      }
      staging = await _createOwnedStaging(lease);
      await data.materialize(staging.database, pendingCleanup: false);
      await data.validateReadBack(staging.database, pendingCleanup: false);
      lease.check();
      if (previewGeneration != generation ||
          !data.hasCurrentTimeAuthority(_now())) {
        throw const DataOperationException(DataOperationFailure.stalePreview);
      }
      lease.update(BackupProcessingPhase.preview);
      return BackupRestoreCandidate._(
        data,
        data.preview,
        previewGeneration,
        revision,
        staging,
        lease,
      );
    } catch (original) {
      try {
        await cleanup();
      } catch (error) {
        lease.retainCleanup(cleanup);
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: error,
        );
      }
      rethrow;
    }
  }

  /// Explicit memory output adapter retained for fixtures and small callers.
  Future<Uint8List> createEncryptedBackup(String password) async {
    BackupPassword.parse(password);
    final lease = _processingOwner.acquire()..beginOperation();
    _PreparedExport? prepared;
    Object? original;
    try {
      prepared = await _prepareExport(lease);
      final output = BytesBuilder(copy: false);
      await for (final chunk in _encryptedExport(prepared, password)) {
        output.add(chunk);
      }
      return output.takeBytes();
    } catch (error) {
      original = error;
      rethrow;
    } finally {
      try {
        await _finishExport(prepared, lease, original: original);
      } finally {
        lease.endOperation();
      }
    }
  }

  Future<int> _currentRevision() async => (await (_database.select(
    _database.users,
  )..where((t) => t.id.equals(localProfileId))).getSingle()).dataRevision;

  Future<void> applyRestore(BackupRestoreCandidate candidate) async {
    await applyRestoreWithReceipt(candidate);
  }

  Future<int> applyRestoreWithReceipt(BackupRestoreCandidate candidate) {
    if (candidate._consumed) {
      return Future.error(
        const DataOperationException(DataOperationFailure.stalePreview),
      );
    }
    if (candidate._running != null) return candidate._running!;
    candidate._lease.beginOperation();
    return candidate._running = _claimRestore(candidate).whenComplete(() {
      candidate._running = null;
      candidate._lease.endOperation();
    });
  }

  Future<int> _claimRestore(BackupRestoreCandidate candidate) async {
    var claimed = false;
    var claimGeneration = candidate._generation;
    try {
      return await _operationGate.run(
        () async {
          claimed = true;
          candidate._lease.cancellationAllowed = false;
          candidate._lease.update(BackupProcessingPhase.applying);
          claimGeneration = generation;
          await _applyRestore(candidate);
          candidate._consumed = true;
          _pendingStagingCleanup.add(candidate);
          // A committed restore is never retried as another data replacement.
          try {
            await finishRestoreCleanup();
          } catch (_) {
            _operationGate.setRecoveryPending(true);
          }
          return claimGeneration;
        },
        replacesData: true,
        validateReplacement: () async {
          if (!candidate._data.hasCurrentTimeAuthority(_now()) ||
              candidate._generation != generation ||
              candidate._revision != await _currentRevision()) {
            throw const DataOperationException(
              DataOperationFailure.stalePreview,
            );
          }
        },
      );
    } catch (error) {
      if (error is BackupRestoreCommitUncertain) rethrow;
      if (!claimed) rethrow;
      // The old generation and OS cleanup may already have changed, even when
      // the DB transaction rejects an edit that raced the cleanup. A09 owns
      // complete writer fencing and staging/runtime replacement integration.
      candidate._generation = claimGeneration;
      throw DataOperationException(
        error is DataOperationException
            ? error.failure
            : DataOperationFailure.failed,
        followUpPending: true,
        generation: claimGeneration,
      );
    }
  }

  Future<void> finishRestoreCleanup() async {
    if (_restoreCommitUndetermined) {
      throw BackupRestoreCommitUncertain(generation: generation);
    }
    await _runtimeIdentity.cleanup(
      _database,
      _operationGate,
      cleanupPlatform: () async {
        await (_cleanupPlatform ??
            () => cleanupRestoreDeliveries(_cancelAllAlarms.operations))();
        // Keep the durable pending marker until both OS/runtime cleanup and the
        // candidate's encrypted staging file have been released successfully.
        for (final staging in _pendingStagingCleanup.toList()) {
          await staging._releaseResources();
          _pendingStagingCleanup.remove(staging);
        }
      },
    );
  }

  Future<void> _applyRestore(BackupRestoreCandidate candidate) async {
    try {
      await _cancelAllAlarms.forDataReplacement();
    } on AlarmCleanupIncomplete {
      // Returned failure is distinct from an outstanding native Future.
      // Ownership journal still blocks same-ID replacement until confirmed.
    }
    User? original;
    User? attempted;
    try {
      await _database.transaction(() async {
        original = await _database.select(_database.users).getSingle();
        if (!candidate._data.hasCurrentTimeAuthority(_now()) ||
            candidate._revision != await _currentRevision()) {
          throw const DataOperationException(DataOperationFailure.stalePreview);
        }
        await _database.deleteAllDurableData();
        await copyPortableBackupRows(
          candidate._staging.database,
          _database,
          budget: candidate._data.budget,
        );
        final durableMarker = candidate._data.metadata.cutoffLiteral == null
            ? candidate._data.metadata.cutoff
            : DateTime.now().toUtc();
        await (_database.update(
          _database.users,
        )..where((u) => u.id.equals(localProfileId))).write(
          UsersCompanion(
            restoreCleanupPending: const Value(true),
            rejectLegacyDelivery: const Value(true),
            firstDurableDataAt: Value(durableMarker),
            lastDurableDataAt: Value(durableMarker),
          ),
        );
        await _database.customStatement(
          "UPDATE schedules SET requires_start_confirmation=1 WHERE done_status='notEnded'",
        );
        attempted = await _database.select(_database.users).getSingle();
      });
    } catch (_) {
      // If the callback did not finish, Drift never attempted its outer COMMIT.
      // Once it did finish, an exception may only be a lost commit response.
      if (attempted == null) rethrow;
      User? current;
      try {
        current = await _database.select(_database.users).getSingleOrNull();
      } catch (_) {
        await _holdUnknownRestore(candidate);
        throw BackupRestoreCommitUncertain(generation: generation);
      }
      if (current == original) rethrow; // Authoritative rollback read-back.
      if (current != attempted) {
        await _holdUnknownRestore(candidate);
        throw BackupRestoreCommitUncertain(generation: generation);
      }
      // The exact new profile includes a fresh store incarnation and the
      // pending cleanup marker written with all portable rows atomically.
      // Continue the committed path; never apply this candidate a second time.
    }
    _operationGate.setRecoveryPending(true);
  }

  Future<void> _holdUnknownRestore(BackupRestoreCandidate candidate) async {
    _restoreCommitUndetermined = true;
    _operationGate.setRecoveryPending(true);
    _runtimeIdentity.pending = true;
    candidate._consumed = true;
    // Provisional resources are no longer needed for another import. Existing
    // lease cleanup retains any failure; durable authority waits for restart.
    try {
      await candidate._releaseResources();
    } catch (_) {
      // Cleanup failure cannot turn an unknown replacement into a rollback.
    }
  }

  Future<BackupFreshnessStatus> getFreshness() async {
    final user = await (_database.select(
      _database.users,
    )..where((table) => table.id.equals(localProfileId))).getSingleOrNull();
    if (user?.lastExportedRevision == null) {
      return BackupFreshnessStatus(
        freshness: BackupFreshness.neverExported,
        reminderDue: _isOlderThanReminderBoundary(user?.firstDurableDataAt),
      );
    }
    return BackupFreshnessStatus(
      freshness: user!.lastExportedRevision == user.dataRevision
          ? BackupFreshness.noChanges
          : BackupFreshness.unexportedChanges,
      lastExportedAt: user.lastExportedAt,
      reminderDue:
          user.lastExportedRevision != user.dataRevision &&
          _isOlderThanReminderBoundary(user.lastDurableDataAt),
    );
  }

  bool _isOlderThanReminderBoundary(DateTime? value) =>
      value != null && DateTime.now().difference(value).inDays >= 30;

  String _fileDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  String _sourcePlatform() {
    try {
      return DeviceInfoService.platformType.name;
    } catch (_) {
      return 'unknown';
    }
  }
}

class _PreparedExport {
  _PreparedExport(
    this.snapshot,
    this.budget,
    this.length,
    this.digest,
    this.generation,
  );
  final BackupExportSnapshot snapshot;
  final BackupBudget budget;
  final int length;
  final Digest digest;
  final int generation;
}

class _ExportDigest implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
