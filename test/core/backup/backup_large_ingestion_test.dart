// Structured synthetic QA evidence is intentionally emitted to captured logs.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/backup/backup_file_export_port.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import '../../helpers/sodium_test_loader.dart';
import 'backup_validation_contract_test.dart' show validBackup;

Stream<List<int>> fixture() async* {
  final header = validBackup()..remove('schedules');
  final json = jsonEncode(header);
  yield utf8.encode('${json.substring(0, json.length - 1)},"schedules":[');
  final prototype = (validBackup()['schedules'] as List).single as Map;
  for (var i = 0; i < 10000; i++) {
    yield utf8.encode(
      '${i == 0 ? '' : ','}${jsonEncode({
        ...prototype,
        'id': 'schedule-$i',
        'place': {'id': 'place-$i', 'name': 'Fixture $i'},
      })}',
    );
  }
  yield utf8.encode(']}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY'];
  if (library != null) open.overrideForAll(() => DynamicLibrary.open(library));
  test(
    '10000 actual encrypted records authenticate, materialize and bounded read back within original budgets',
    () async {
      final root = await Directory.systemTemp.createTemp('d05-large-');
      addTearDown(() => root.delete(recursive: true));
      var plaintextLength = 0;
      await for (final chunk in fixture()) {
        plaintextLength += chunk.length;
      }
      final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
      const password = 'D05 synthetic large fixture password';
      final file = File('${root.path}/fixture.ontimebackup');
      final sink = file.openWrite();
      final total = Stopwatch()..start();
      await sink.addStream(
        crypto.encryptStream(
          plaintext: fixture(),
          plaintextLength: plaintextLength,
          password: password,
        ),
      );
      await sink.flush();
      await sink.close();
      final productionStartRss = ProcessInfo.currentRss;
      final phase = Stopwatch()..start();
      final budget = BackupBudget();
      final content = await BackupValidatedIngestion.decrypt(
        ciphertext: file.openRead(),
        password: password,
        crypto: crypto,
        budget: budget,
        nowUtc: DateTime.utc(2026, 9, 24),
        createStore: (budget) => BackupIngestionStore.create(
          budget,
          root: Directory('${root.path}/ingestion'),
        ),
      );
      addTearDown(content.release);
      final ingestionMs = phase.elapsedMilliseconds;
      final rawBytes = await Directory('${root.path}/ingestion')
          .list()
          .where((e) => e is File)
          .asyncMap((e) => (e as File).length())
          .fold<int>(0, (a, b) => a + b);
      final stage = await RestoreStaging.create(
        root: Directory('${root.path}/materialized'),
      );
      addTearDown(stage.release);
      await content.materialize(stage.database, pendingCleanup: false);
      final materializedMs = phase.elapsedMilliseconds - ingestionMs;
      await content.validateReadBack(stage.database, pendingCleanup: false);
      expect(content.preview.scheduleCount, 10000);
      expect(
        (await stage.database
                .customSelect('SELECT count(*) AS n FROM schedules')
                .getSingle())
            .read<int>('n'),
        10000,
      );
      final first = await (stage.database.customSelect(
        "SELECT schedule_name,place_id FROM schedules WHERE id='schedule-0'",
      )).getSingle();
      final last = await (stage.database.customSelect(
        "SELECT schedule_name,place_id FROM schedules WHERE id='schedule-9999'",
      )).getSingle();
      expect(first.read<String>('place_id'), 'place-0');
      expect(last.read<String>('place_id'), 'place-9999');
      expect(budget.work, lessThanOrEqualTo(BackupLimits.work));
      final readbackMs =
          phase.elapsedMilliseconds - ingestionMs - materializedMs;
      final exported = File('${root.path}/roundtrip.ontimebackup');
      final exportFile = await exported.open(mode: FileMode.write);
      addTearDown(exportFile.close);
      var channelSequence = 0;
      var maxChannel = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(NativeBackupFileExportPort.channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        switch (call.method) {
          case 'begin':
            return 'synthetic-export-attempt';
          case 'append':
            expect(args['sequence'], channelSequence++);
            final bytes = args['bytes'] as Uint8List;
            expect(bytes.length, lessThanOrEqualTo(65536));
            if (bytes.length > maxChannel) maxChannel = bytes.length;
            await exportFile.writeFrom(bytes);
            return true;
          case 'seal':
            await exportFile.flush();
            expect(await exported.length(), args['length']);
            expect(
              (await sha256.bind(exported.openRead()).single).toString(),
              args['sha256'],
            );
            return true;
          case 'export':
            return {'outcome': 'saved', 'cleanupUnconfirmed': false};
          case 'cancel':
            return {'outcome': 'cancelled', 'cleanupUnconfirmed': false};
          default:
            fail('unexpected native method');
        }
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          NativeBackupFileExportPort.channel,
          null,
        ),
      );
      BackupBudget? exportBudget;
      final service = BackupService(
        stage.database,
        _Metadata(),
        NoopAlarmCleanup(),
        crypto: crypto,
        processingOwner: BackupProcessingOwner(),
        operationGate: LocalDataOperationGate(),
        stagingFactory: () => RestoreStaging.create(
          root: Directory('${root.path}/export-snapshot'),
        ),
        ingestionFactory: (b) {
          exportBudget = b;
          return BackupIngestionStore.create(
            b,
            root: Directory('${root.path}/export-validation'),
          );
        },
      );
      final exportStart = Stopwatch()..start();
      expect(
        await service.exportToUserSelectedFile(password),
        BackupExportResult.saved,
      );
      expect(exportBudget!.work, lessThanOrEqualTo(BackupLimits.work));
      final reimportBudget = BackupBudget();
      final reimport = await BackupValidatedIngestion.decrypt(
        ciphertext: exported.openRead(),
        password: password,
        crypto: crypto,
        budget: reimportBudget,
        createStore: (b) => BackupIngestionStore.create(
          b,
          root: Directory('${root.path}/reimport'),
        ),
      );
      addTearDown(reimport.release);
      expect(reimport.preview.scheduleCount, 10000);
      print(
        'D05_LARGE_EXPORT_ROUNDTRIP ${jsonEncode({'exportWork': exportBudget!.work, 'exportFirstPassBytes': exportBudget!.plainBytes, 'exportCipherBytes': await exported.length(), 'channelMaxBytes': maxChannel, 'channelMessages': channelSequence, 'exportAndReimportMs': exportStart.elapsedMilliseconds, 'reimportWork': reimportBudget.work, 'scope': 'actual host SQLCipher + actual crypto; native channel/file seal mock, not OS provider'})}',
      );
      print(
        'D05_LARGE_HOST_SQLCIPHER ${jsonEncode({'schedules': 10000, 'plaintextBytes': plaintextLength, 'ciphertextBytes': await file.length(), 'rawEncryptedStoreBytes': rawBytes, 'records': budget.records, 'work': budget.work, 'largestTrackedBufferBytes': budget.largestTrackedBufferBytes, 'ingestionMs': ingestionMs, 'materializationMs': materializedMs, 'readbackMs': readbackMs, 'fixtureElapsedMs': total.elapsedMilliseconds, 'rssBeforeProductionIngestion': productionStartRss, 'rssAfterReadback': ProcessInfo.currentRss, 'hostProcessPeakAcrossFixture': ProcessInfo.maxRss, 'measurementScope': 'Flutter host test process includes fixture crypto producer; not mobile or isolated parser RSS'})}',
      );
    },
    skip: library == null
        ? 'Requires actual SQLCipher library; not counted as a pass without it'
        : false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.1', buildNumber: '1');
}
