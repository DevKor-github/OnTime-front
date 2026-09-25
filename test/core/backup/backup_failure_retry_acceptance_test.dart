import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/restore_staging_fixture.dart';
import '../../helpers/sodium_test_loader.dart';
import 'backup_crypto_stream_test.dart' as fixture;
import 'backup_validation_contract_test.dart' show validBackup;

// Contract: an unsuccessful preview cannot mutate the active data or runtime,
// and must release its resource lease so the same service can retry normally.
// Memory staging is explicit: this is not encrypted staging or OS evidence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'Synthetic T03 service password';
  const sensitiveNote = 'Synthetic private sentinel never shown in failure';
  late AppDatabase database;
  late BackupService service;
  late LocalDataOperationGate gate;
  late BackupProcessingOwner processing;
  late RestoreRuntimeIdentity runtime;
  late _ObservedCleanup cleanup;
  late BackupCrypto crypto;
  late Uint8List valid;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'early_start_session_sentinel': 'synthetic runtime retained',
    });
    database = AppDatabase.forTesting(NativeDatabase.memory());
    gate = LocalDataOperationGate();
    processing = BackupProcessingOwner();
    runtime = RestoreRuntimeIdentity();
    cleanup = _ObservedCleanup();
    crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration(minutes: 7),
        note: sensitiveNote,
        eligibleOutcomeCount: 4,
        onTimeOutcomeCount: 3,
        isOnboardingCompleted: true,
      ),
    );
    await database.preparationUserDao.createPreparationUser(
      const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'active-step',
            preparationName: 'Synthetic active step',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
      'local-profile',
    );
    await database.scheduleDao.createSchedule(
      ScheduleEntity(
        id: 'active-schedule',
        place: const PlaceEntity(
          id: 'active-place',
          placeName: 'Synthetic active place',
        ),
        scheduleName: 'Synthetic active schedule',
        timeZoneId: 'Asia/Seoul',
        occurrenceOffsetSeconds: 32400,
        scheduleTime: DateTime(2026, 9, 2, 10),
        moveTime: const Duration(minutes: 20),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 5),
        scheduleNote: sensitiveNote,
      ).toScheduleWithPlaceRow(),
    );
    await runtime.load(database);
    service = BackupService(
      database,
      _Metadata(),
      cleanup,
      crypto: crypto,
      ingestionFactory: memoryBackupIngestion,
      processingOwner: processing,
      stagingFactory: memoryRestoreStaging,
      runtimeIdentity: runtime,
      cleanupPlatform: noPlatformRestoreCleanup,
      operationGate: gate,
    );
    valid = await crypto.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(validBackup()))),
      password: password,
    );
  });
  tearDown(() => database.close());

  test(
    'T03 C12 failure classes preserve active rows and same-service preview retry succeeds',
    () async {
      final before = await _logicalRows(database);
      final generation = gate.generation;
      final identity = runtime.storeIncarnation;
      final rejectLegacy = runtime.rejectLegacy;
      final pending = runtime.pending;
      final prefs = await SharedPreferences.getInstance();
      final prefsBefore = {
        for (final key in prefs.getKeys()) key: prefs.get(key),
      };
      Future<Uint8List> encode(Object input) => crypto.encrypt(
        plaintext: Uint8List.fromList(utf8.encode(jsonEncode(input))),
        password: password,
      );
      final unsupported = validBackup()..['formatVersion'] = 999;
      final invalidGraph = validBackup();
      invalidGraph['defaultPreparation'] = [
        {'id': 'a', 'name': 'Synthetic step', 'minutes': 1, 'nextId': 'a'},
      ];
      final frames = fixture.frames(valid);
      final tampered = Uint8List.fromList(valid)..[valid.length - 1] ^= 1;
      final variants = <(String, Uint8List, String)>[
        ('wrong password', valid, 'Synthetic wrong password'),
        ('ciphertext authentication', tampered, password),
        (
          'missing final',
          fixture.withFrames(valid, frames.sublist(0, frames.length - 1)),
          password,
        ),
        ('trailing ciphertext', Uint8List.fromList([...valid, 0]), password),
        (
          'authenticated invalid JSON',
          await crypto.encrypt(
            plaintext: Uint8List.fromList(utf8.encode('{')),
            password: password,
          ),
          password,
        ),
        ('unsupported payload version', await encode(unsupported), password),
        ('invalid preparation graph', await encode(invalidGraph), password),
      ];
      for (final (label, bytes, suppliedPassword) in variants) {
        Object? failure;
        try {
          final unexpected = await service.previewEncryptedBackup(
            bytes,
            suppliedPassword,
          );
          await unexpected.dispose();
          fail('$label unexpectedly produced a preview');
        } on BackupProcessingFailure catch (error) {
          failure = error;
        }
        expect(failure, isA<BackupProcessingFailure>(), reason: label);
        for (final secret in [password, suppliedPassword, sensitiveNote]) {
          expect(failure.toString(), isNot(contains(secret)), reason: label);
        }
        expect(processing.active, isNull, reason: label);
        expect(gate.isAvailable, isTrue, reason: label);
        expect(gate.generation, generation, reason: label);
        expect(await _logicalRows(database), before, reason: label);
        expect(runtime.storeIncarnation, identity, reason: label);
        expect(runtime.rejectLegacy, rejectLegacy, reason: label);
        expect(runtime.pending, pending, reason: label);
        expect(cleanup.calls, 0, reason: label);
        await prefs.reload();
        expect(
          {for (final key in prefs.getKeys()) key: prefs.get(key)},
          prefsBefore,
          reason: label,
        );
        final candidate = await service.previewEncryptedBackup(valid, password);
        expect(
          processing.active?.phase,
          BackupProcessingPhase.preview,
          reason: label,
        );
        expect(candidate.preview.scheduleCount, 1, reason: label);
        await candidate.dispose();
        expect(processing.active, isNull, reason: label);
        expect(
          await _logicalRows(database),
          before,
          reason: '$label retry is preview only',
        );
        expect(gate.generation, generation, reason: label);
        expect(cleanup.calls, 0, reason: label);
      }
    },
  );
}

Future<Map<String, List<Map<String, Object?>>>> _logicalRows(
  AppDatabase db,
) async {
  final result = <String, List<Map<String, Object?>>>{};
  for (final table in db.allTables) {
    final name = table.actualTableName;
    final rows = await db
        .customSelect('SELECT * FROM "$name" ORDER BY rowid')
        .get();
    result[name] = rows
        .map((row) => Map<String, Object?>.from(row.data))
        .toList();
  }
  return result;
}

class _ObservedCleanup extends NoopAlarmCleanup {
  int calls = 0;
  @override
  Future<void> call() async {
    calls++;
  }

  @override
  Future<void> forDataReplacement() async {
    calls++;
  }
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.1', buildNumber: '1');
}
