// Structured synthetic QA evidence is intentionally emitted to captured logs.
// ignore_for_file: avoid_print
// Separate D05 QA bundle only: synthetic schedules, no user installation/data.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/ports/backup_file_export_port.dart';
import 'package:on_time_front/domain/ports/backup_file_import_port.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';

const _password = 'D05 synthetic cross-platform backup password';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('D05 synthetic backup probe'))),
    ),
  );
  final documents = await getApplicationDocumentsDirectory();
  if (await File('${documents.path}/d05-cross-only').exists()) {
    await _crossOnly(documents);
    return;
  }
  final result = File('${documents.path}/d05-backup-result.json');
  final owned = Directory('${documents.path}/d05-owned');
  final rows = <Map<String, Object?>>[];
  var phase = 'initializing';
  final timer = Stopwatch()..start();
  try {
    await owned.create(recursive: true);
    final crypto = BackupCrypto();
    final baselineRss = ProcessInfo.currentRss;
    phase = 'fixture-crypto';
    var size = 0;
    await for (final part in _fixture()) {
      size += part.length;
    }
    final fixture = File('${owned.path}/fixture.cipher');
    final sink = fixture.openWrite();
    await sink.addStream(
      crypto.encryptStream(
        plaintext: _fixture(),
        plaintextLength: size,
        password: _password,
      ),
    );
    await sink.flush();
    await sink.close();
    phase = 'common-ingestion';
    final budget = BackupBudget();
    final ingestionStart = timer.elapsedMilliseconds;
    final data = await BackupValidatedIngestion.decrypt(
      ciphertext: fixture.openRead(),
      password: _password,
      crypto: crypto,
      budget: budget,
      createStore: (b) => BackupIngestionStore.create(
        b,
        root: Directory('${owned.path}/ingestion'),
      ),
    );
    rows.add({
      'phase': phase,
      'ms': timer.elapsedMilliseconds - ingestionStart,
      'work': budget.work,
      'rss': ProcessInfo.currentRss,
    });
    phase = 'materialize';
    final materializeStart = timer.elapsedMilliseconds;
    final active = await RestoreStaging.create(
      root: Directory('${owned.path}/active'),
    );
    await data.materialize(active.database, pendingCleanup: false);
    await data.validateReadBack(active.database, pendingCleanup: false);
    rows.add({
      'phase': phase,
      'ms': timer.elapsedMilliseconds - materializeStart,
      'work': budget.work,
      'rss': ProcessInfo.currentRss,
    });
    await data.release();
    final output = File(
      '${documents.path}/d05-export-${Platform.operatingSystem}.ontimebackup',
    );
    final owner = BackupProcessingOwner();
    BackupBudget? exportBudget;
    final service = BackupService(
      active.database,
      _Metadata(),
      _NoAlarms(),
      crypto: crypto,
      processingOwner: owner,
      operationGate: LocalDataOperationGate(),
      runtimeIdentity: RestoreRuntimeIdentity(),
      cleanupPlatform: () async {},
      exportPort: _OwnedOutput(output),
      importPort: _OwnedInput(output),
      stagingFactory: () =>
          RestoreStaging.create(root: Directory('${owned.path}/candidate')),
      ingestionFactory: (b) {
        exportBudget = b;
        return BackupIngestionStore.create(
          b,
          root: Directory('${owned.path}/service-ingestion'),
        );
      },
    );
    phase = 'service-export';
    final exportStart = timer.elapsedMilliseconds;
    if (await service.exportToUserSelectedFile(_password) !=
        BackupExportResult.saved) {
      throw StateError('save');
    }
    rows.add({
      'phase': phase,
      'ms': timer.elapsedMilliseconds - exportStart,
      'work': exportBudget!.work,
      'plaintextBytes': exportBudget!.plainBytes,
      'cipherBytes': await output.length(),
      'rss': ProcessInfo.currentRss,
    });
    phase = 'service-preview-apply';
    final restoreStart = timer.elapsedMilliseconds;
    final candidate = await service.selectAndPreviewRestore(_password);
    if (candidate?.preview.scheduleCount != 10000) throw StateError('count');
    await service.applyRestore(candidate!);
    if (owner.active != null) throw StateError('lease');
    final count =
        (await active.database
                .customSelect('SELECT count(*) AS n FROM schedules')
                .getSingle())
            .read<int>('n');
    if (count != 10000) throw StateError('restored count');
    final user = await active.database
        .select(active.database.users)
        .getSingle();
    if (user.restoreCleanupPending) throw StateError('pending');
    rows.add({
      'phase': phase,
      'ms': timer.elapsedMilliseconds - restoreStart,
      'work': exportBudget!.work,
      'rss': ProcessInfo.currentRss,
      'count': count,
    });
    final cross = File('${documents.path}/d05-cross-input.ontimebackup');
    if (await cross.exists()) {
      phase = 'cross-platform-input';
      final crossStart = timer.elapsedMilliseconds;
      final crossData = await BackupValidatedIngestion.decrypt(
        ciphertext: cross.openRead(),
        password: _password,
        crypto: crypto,
        budget: BackupBudget(),
        createStore: (b) => BackupIngestionStore.create(
          b,
          root: Directory('${owned.path}/cross'),
        ),
      );
      if (crossData.preview.scheduleCount != 10000) {
        throw StateError('cross count');
      }
      final crossStage = await RestoreStaging.create(
        root: Directory('${owned.path}/cross-candidate'),
      );
      await crossData.materialize(crossStage.database, pendingCleanup: false);
      await crossData.validateReadBack(
        crossStage.database,
        pendingCleanup: false,
      );
      rows.add({
        'phase': phase,
        'ms': timer.elapsedMilliseconds - crossStart,
        'sourcePlatform': crossData.preview.sourcePlatform,
        'count': crossData.preview.scheduleCount,
      });
      await crossData.release();
      await crossStage.release();
    }
    final cipher =
        (await active.database
                .customSelect('PRAGMA cipher_version')
                .getSingle())
            .data
            .values
            .single;
    await active.release();
    await fixture.delete();
    final remainder = await owned
        .list(recursive: true)
        .where((entry) => entry is File)
        .toList();
    if (remainder.isNotEmpty) throw StateError('temporary residue');
    final report = {
      'passed': true,
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'cipher': cipher,
      'elapsedMs': timer.elapsedMilliseconds,
      'baselineRss': baselineRss,
      'finalRss': ProcessInfo.currentRss,
      'processPeakRss': ProcessInfo.maxRss,
      'phases': rows,
      'scope':
          'Actual mobile SQLCipher, sodium and bounded normal BackupService export/preview/apply. QA owned-file ports and no-alarm cleanup; not actual system picker/provider or user runtime alarms. Peak includes fixture producer and Flutter rendering.',
    };
    await result.writeAsString(jsonEncode(report));
    print('D05_BACKUP_MOBILE ${jsonEncode(report)}');
  } catch (error, stack) {
    final report = {
      'passed': false,
      'phase': phase,
      'error': error.toString(),
      'stack': stack.toString(),
      'phases': rows,
    };
    await result.writeAsString(jsonEncode(report));
    print('D05_BACKUP_MOBILE ${jsonEncode(report)}');
  }
}

Stream<List<int>> _fixture() async* {
  yield utf8.encode(
    jsonEncode({
      'formatVersion': 1,
      'cutoff': '2026-09-24T00:00:00Z',
      'sourceAppVersion': 'D05 synthetic',
      'sourcePlatform': 'fixture',
      'dataRevision': 1,
      'profile': {
        'spareTimeMinutes': 0,
        'note': 'synthetic',
        'isOnboardingCompleted': true,
        'eligibleOutcomeCount': 0,
        'onTimeOutcomeCount': 0,
      },
      'preferences': {
        'alarmsEnabled': false,
        'alarmOffsetMinutes': 0,
        'detailedNotificationContent': false,
      },
      'defaultPreparation': [
        {'id': 'step', 'name': 'Prepare', 'minutes': 0, 'nextId': null},
      ],
      'schedulePreparations': {},
      'templates': [],
    }).replaceFirst(RegExp(r'}$'), ',"schedules":['),
  );
  for (var i = 0; i < 10000; i++) {
    yield utf8.encode(
      '${i == 0 ? '' : ','}${jsonEncode({
        'id': 'schedule-$i',
        'place': {'id': 'place-$i', 'name': 'Fixture $i'},
        'name': 'Meeting',
        'civilTime': '2026-09-01T09:00:00Z',
        'timeZoneId': 'Asia/Seoul',
        'occurrenceOffsetSeconds': 32400,
        'moveTimeMinutes': 0,
        'spareTimeMinutes': 0,
        'isChanged': false,
        'note': '',
        'latenessTime': -1,
        'doneStatus': 'notEnded',
        'preparationTemplateDeleted': false,
        'scoreContributionRecorded': false,
      })}',
    );
  }
  yield utf8.encode(']}');
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: 'D05 QA', buildNumber: '1');
}

class _NoAlarms implements CancelAllAlarmsUseCase {
  @override
  AlarmOperationCoordinator get operations =>
      throw UnsupportedError('No alarm registrations in this synthetic QA');
  @override
  Future<T> withCleanupOwner<T>(
    Future<T> Function(AlarmRegistrationCleanup) action,
  ) => throw UnsupportedError('No alarm registrations in this synthetic QA');
  @override
  Future<void> call() async {}
  @override
  Future<void> forDataReplacement() async {}
}

class _OwnedOutput implements BackupFileExportPort {
  _OwnedOutput(this.file);
  final File file;
  @override
  Future<BackupFileExportReceipt> exportStream({
    required Stream<List<int>> encrypted,
    required String suggestedName,
    BackupProcessingLease? lease,
  }) async {
    final sink = file.openWrite();
    try {
      await sink.addStream(encrypted);
      await sink.flush();
    } finally {
      await sink.close();
    }
    return BackupFileExportReceipt.saved;
  }
}

class _OwnedInput implements BackupFileImportPort {
  _OwnedInput(this.file);
  final File file;
  @override
  Future<BackupImportSource?> select({BackupProcessingLease? lease}) async =>
      _OwnedSource(file, await file.length());
}

class _OwnedSource implements BackupImportSource {
  _OwnedSource(this.file, this.declaredLength);
  final File file;
  @override
  final int declaredLength;
  @override
  Stream<Uint8List> openRead() => file.openRead().map(Uint8List.fromList);
  @override
  Future<void> close() async {}
}

Future<void> _crossOnly(Directory documents) async {
  final timer = Stopwatch()..start();
  final result = File('${documents.path}/d05-cross-result.json');
  final root = Directory('${documents.path}/d05-cross-owned');
  try {
    final input = File('${documents.path}/d05-cross-input.ontimebackup');
    final budget = BackupBudget();
    final data = await BackupValidatedIngestion.decrypt(
      ciphertext: input.openRead(),
      password: _password,
      crypto: BackupCrypto(),
      budget: budget,
      createStore: (b) => BackupIngestionStore.create(b, root: root),
    );
    final stage = await RestoreStaging.create(root: root);
    await data.materialize(stage.database, pendingCleanup: false);
    await data.validateReadBack(stage.database, pendingCleanup: false);
    final count =
        (await stage.database
                .customSelect('SELECT count(*) AS n FROM schedules')
                .getSingle())
            .read<int>('n');
    if (count != 10000 ||
        data.preview.sourcePlatform == Platform.operatingSystem) {
      throw StateError('wrong cross fixture');
    }
    final source = data.preview.sourcePlatform;
    await data.release();
    await stage.release();
    if (await root.list().any((entry) => entry is File)) {
      throw StateError('cross residue');
    }
    final report = {
      'passed': true,
      'targetPlatform': Platform.operatingSystem,
      'sourcePlatform': source,
      'count': count,
      'inputBytes': await input.length(),
      'work': budget.work,
      'elapsedMs': timer.elapsedMilliseconds,
      'processPeakRss': ProcessInfo.maxRss,
      'scope':
          'Actual foreign mobile ciphertext authenticated and fully validated/materialized/read back with SQLCipher; QA-owned input file, not system picker.',
    };
    await result.writeAsString(jsonEncode(report));
    print('D05_CROSS_MOBILE ${jsonEncode(report)}');
  } catch (error, stack) {
    final report = {
      'passed': false,
      'error': error.toString(),
      'stack': stack.toString(),
    };
    await result.writeAsString(jsonEncode(report));
    print('D05_CROSS_MOBILE ${jsonEncode(report)}');
  }
}
