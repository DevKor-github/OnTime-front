import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/restore_staging_fixture.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import '../../helpers/noop_alarm_cleanup.dart';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/core/backup/backup_file_import_port.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

import '../../helpers/sodium_test_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'synthetic portable backup password';
  late AppDatabase database;
  late BackupService service;
  late _Picker picker;
  late Map<String, List<Map<String, Object?>>> before;

  Future<Map<String, List<Map<String, Object?>>>> snapshot() async => {
    for (final table in database.allTables)
      table.actualTableName: [
        for (final row
            in await database
                .customSelect('SELECT * FROM "${table.actualTableName}"')
                .get())
          row.data,
      ],
  };

  setUp(() async {
    picker = _Picker();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          NativeBackupFileImportPort.channel,
          picker.handle,
        );
    database = AppDatabase.forTesting(NativeDatabase.memory());
    service = BackupService(
      database,
      _Metadata(),
      NoopAlarmCleanup(),
      stagingFactory: memoryRestoreStaging,
      ingestionFactory: memoryBackupIngestion,
      processingOwner: testBackupProcessingOwner(),
      runtimeIdentity: RestoreRuntimeIdentity(),
      cleanupPlatform: noPlatformRestoreCleanup,
      crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
    );
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration(minutes: 7),
        note: 'synthetic sentinel, preserve until final confirmation',
      ),
    );
    await database.preparationUserDao.createPreparationUser(
      const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'fixture-step',
            preparationName: 'Synthetic pack',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
      'local-profile',
    );
    await database.scheduleDao.createSchedule(
      ScheduleEntity(
        id: 'fixture-schedule',
        place: const PlaceEntity(id: 'fixture-place', placeName: 'Fixture'),
        scheduleName: 'Synthetic appointment',
        timeZoneId: 'Asia/Seoul',
        occurrenceOffsetSeconds: 9 * 60 * 60,
        scheduleTime: DateTime(2026, 10, 1, 10),
        moveTime: const Duration(minutes: 10),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 3),
        scheduleNote: '',
      ).toScheduleWithPlaceRow(),
    );
    // Verify preservation of existing successful-export metadata as well as
    // user content on every selection, preview and failure path.
    await database.userDao.markExported(
      userId: 'local-profile',
      revision: 0,
      cutoff: DateTime.utc(2026, 9, 23),
    );
    before = await snapshot();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeBackupFileImportPort.channel, null);
    await database.close();
  });
  test(
    'cancel closes opaque native attempt without decrypting and permits another selection',
    () async {
      expect(await service.selectAndPreviewRestore('short'), isNull);
      expect(picker.closes, 1);
      expect(await snapshot(), before);
      picker.bytes = await service.createEncryptedBackup(password);
      final candidate = await service.selectAndPreviewRestore(password);
      expect(candidate!.preview.scheduleCount, 1);
      expect(candidate.preview.defaultPreparationStepCount, 1);
      expect(candidate.preview.sourceAppVersion, '1.0.0+1');
      expect(await snapshot(), before);
      expect(picker.calls, 2);
      expect(picker.closes, 2);
      await candidate.dispose();
    },
  );
  test(
    'selected opaque source authenticates before preview and closes at actual EOF',
    () async {
      picker.bytes = await service.createEncryptedBackup(password);
      picker.shortReads = true;
      final candidate = await service.selectAndPreviewRestore(password);
      expect(candidate!.preview.scheduleCount, 1);
      expect(picker.eofReads, 1);
      expect(picker.closes, 1);
      expect(await snapshot(), before);
      await candidate.dispose();
    },
  );
  for (final mode in ['ordinary', 'corrupted', 'truncated', 'password']) {
    test(
      '$mode input never changes active data and source is closed',
      () async {
        final encrypted = await service.createEncryptedBackup(password);
        picker.bytes = switch (mode) {
          'ordinary' => Uint8List.fromList('not a backup'.codeUnits),
          'truncated' => Uint8List.sublistView(
            encrypted,
            0,
            encrypted.length - 10,
          ),
          _ => encrypted,
        };
        if (mode == 'corrupted') picker.bytes![picker.bytes!.length - 1] ^= 1;
        await expectLater(
          service.selectAndPreviewRestore(
            mode == 'password' ? 'a different valid length password' : password,
          ),
          throwsFormatException,
        );
        expect(await snapshot(), before);
        expect(picker.closes, 1);
      },
    );
  }
  test(
    'provider read failure is typed, closes and permits retry without writes',
    () async {
      picker.bytes = Uint8List(1);
      picker.readFailure = true;
      await expectLater(
        service.selectAndPreviewRestore(password),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.inputOutput,
          ),
        ),
      );
      expect(await snapshot(), before);
      expect(picker.closes, 1);
      picker.bytes = null;
      picker.readFailure = false;
      expect(await service.selectAndPreviewRestore(password), isNull);
      expect(picker.calls, 2);
    },
  );
}

class _Picker {
  Uint8List? bytes;
  var calls = 0;
  var closes = 0;
  var eofReads = 0;
  var offset = 0;
  bool shortReads = false;
  bool readFailure = false;
  Future<Object?> handle(MethodCall call) async {
    final args = call.arguments as Map?;
    if (call.method != 'begin') expect(args!['handle'], 'opaque-input');
    switch (call.method) {
      case 'begin':
        offset = 0;
        return 'opaque-input';
      case 'pick':
        calls++;
        return bytes == null ? null : {'length': bytes!.length};
      case 'close':
        closes++;
        return true;
      case 'read':
        if (readFailure) {
          throw PlatformException(
            code: 'import_io',
            message: 'private provider path',
          );
        }
        final max = args!['maxBytes'] as int;
        expect(max, inInclusiveRange(1, 65536));
        if (offset == bytes!.length) {
          eofReads++;
          return {'bytes': Uint8List(0), 'eof': true};
        }
        final end = (offset + (shortReads ? 7 : max)).clamp(0, bytes!.length);
        final chunk = Uint8List.sublistView(bytes!, offset, end);
        offset = end;
        return {'bytes': chunk, 'eof': false};
      default:
        fail('unexpected method');
    }
  }
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.0', buildNumber: '1');
}
