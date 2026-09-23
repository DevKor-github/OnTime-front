import '../../helpers/noop_alarm_cleanup.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_selector_ios/file_selector_ios.dart';
// The locked plugin exposes its host fake through this generated API. Keep the
// real FileSelectorIOS UTI conversion between the app and this host boundary.
// ignore: implementation_imports
import 'package:file_selector_ios/src/messages.g.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
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
  const password = 'synthetic portable backup password';
  late FileSelectorPlatform originalPlatform;
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
    originalPlatform = FileSelectorPlatform.instance;
    picker = _Picker();
    FileSelectorPlatform.instance = picker;
    database = AppDatabase.forTesting(NativeDatabase.memory());
    service = BackupService(
      database,
      _Metadata(),
      NoopAlarmCleanup(),
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
    FileSelectorPlatform.instance = originalPlatform;
    await database.close();
  });

  test(
    'app filter reaches real iOS host as public.data; cancel is null',
    () async {
      final host = _IOSHost();
      FileSelectorPlatform.instance = FileSelectorIOS(api: host);

      expect(await service.selectAndPreviewRestore(password), isNull);
      expect(host.calls, 1);
      expect(host.config!.utis, ['public.data']);
      expect(host.config!.allowMultiSelection, isFalse);
      expect(await snapshot(), before);

      // Cancellation does not poison a subsequent picker attempt.
      expect(await service.selectAndPreviewRestore(password), isNull);
      expect(host.calls, 2);
    },
  );

  test(
    'previous extension-only filter fails before reaching iOS host',
    () async {
      final host = _IOSHost();
      final ios = FileSelectorIOS(api: host);

      await expectLater(
        ios.openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'OnTime Backup',
              extensions: ['ontimebackup'],
              mimeTypes: ['application/octet-stream'],
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(host.calls, 0);
    },
  );

  test('app request preserves Android extension and MIME filters', () async {
    expect(await service.selectAndPreviewRestore(password), isNull);
    final group = picker.groups!.single;
    expect(group.extensions, ['ontimebackup']);
    expect(group.mimeTypes, ['application/octet-stream']);
    expect(group.uniformTypeIdentifiers, ['public.data']);
    expect(await snapshot(), before);
  });

  test(
    'cancel does not decrypt and a later valid selection can be previewed',
    () async {
      // Invalid password would fail if cancellation accidentally invoked crypto.
      expect(await service.selectAndPreviewRestore('short'), isNull);
      expect(await snapshot(), before);
      picker.file = XFile.fromData(
        await service.createEncryptedBackup(password),
        name: 'synthetic.ontimebackup',
      );

      final candidate = await service.selectAndPreviewRestore(password);
      expect(candidate!.preview.scheduleCount, 1);
      expect(candidate.preview.defaultPreparationStepCount, 1);
      expect(candidate.preview.sourceAppVersion, '1.0.0+1');
      expect(await snapshot(), before);
      expect(picker.calls, 2);
    },
  );

  test(
    'real iOS selected path is read and authenticated before preview',
    () async {
      final directory = await Directory.systemTemp.createTemp('ontime-a03-');
      addTearDown(() => directory.delete(recursive: true));
      // A renamed valid backup is still judged by its contents, not extension.
      final file = File('${directory.path}/synthetic-renamed.data');
      await file.writeAsBytes(await service.createEncryptedBackup(password));
      final host = _IOSHost()..paths = [file.path];
      FileSelectorPlatform.instance = FileSelectorIOS(api: host);

      final candidate = await service.selectAndPreviewRestore(password);
      expect(candidate!.preview.scheduleCount, 1);
      expect(host.config!.utis, ['public.data']);
      expect(await snapshot(), before);
    },
  );

  test(
    'ordinary file with a backup extension is rejected without writes',
    () async {
      picker.file = XFile.fromData(
        Uint8List.fromList('not an encrypted backup'.codeUnits),
        name: 'synthetic.ontimebackup',
      );

      await expectLater(
        service.selectAndPreviewRestore(password),
        throwsFormatException,
      );
      expect(await snapshot(), before);
    },
  );

  test('corrupted backup is rejected without writes', () async {
    final encrypted = await service.createEncryptedBackup(password);
    encrypted[encrypted.length - 1] ^= 1;
    picker.file = XFile.fromData(encrypted, name: 'corrupt.ontimebackup');

    await expectLater(
      service.selectAndPreviewRestore(password),
      throwsFormatException,
    );
    expect(await snapshot(), before);
  });

  test('truncated backup is rejected without writes', () async {
    final encrypted = await service.createEncryptedBackup(password);
    picker.file = XFile.fromData(
      Uint8List.sublistView(encrypted, 0, encrypted.length - 10),
      name: 'truncated.ontimebackup',
    );

    await expectLater(
      service.selectAndPreviewRestore(password),
      throwsFormatException,
    );
    expect(await snapshot(), before);
  });

  test('wrong password is rejected without writes', () async {
    picker.file = XFile.fromData(
      await service.createEncryptedBackup(password),
      name: 'synthetic.ontimebackup',
    );

    await expectLater(
      service.selectAndPreviewRestore('a different valid length password'),
      throwsFormatException,
    );
    expect(await snapshot(), before);
  });

  test(
    'read failure preserves data and does not prevent another attempt',
    () async {
      picker.file = _UnreadableFile();

      await expectLater(
        service.selectAndPreviewRestore(password),
        throwsA(isA<FileSystemException>()),
      );
      expect(await snapshot(), before);
      picker.file = null;
      expect(await service.selectAndPreviewRestore(password), isNull);
      expect(picker.calls, 2);
    },
  );
}

class _Picker extends FileSelectorPlatform {
  XFile? file;
  List<XTypeGroup>? groups;
  int calls = 0;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    calls++;
    groups = acceptedTypeGroups;
    return file;
  }
}

class _IOSHost extends FileSelectorApi {
  FileSelectorConfig? config;
  List<String> paths = [];
  int calls = 0;

  @override
  Future<List<String>> openFile(FileSelectorConfig config) async {
    calls++;
    this.config = config;
    return paths;
  }
}

class _UnreadableFile extends XFile {
  _UnreadableFile() : super('synthetic-provider-file');

  @override
  Future<Uint8List> readAsBytes() async {
    throw const FileSystemException('Synthetic provider read failure');
  }
}

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.0', buildNumber: '1');
}
