import 'dart:convert';
import 'dart:typed_data';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_file_picker.dart';
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
  const password = 'portable backup password';
  late AppDatabase database;
  late BackupService service;
  late _FilePicker filePicker;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    filePicker = _FilePicker();
    service = BackupService(
      database,
      _MetadataProvider(),
      crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
      filePicker: filePicker,
    );
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration(minutes: 7),
        note: 'local note',
        eligibleOutcomeCount: 4,
        onTimeOutcomeCount: 3,
        isOnboardingCompleted: true,
      ),
    );
    await database.preparationUserDao.createPreparationUser(
      const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'default-step',
            preparationName: 'Pack',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
      'local-profile',
    );
    await database.scheduleDao.createSchedule(
      _schedule().toScheduleWithPlaceRow(),
    );
  });

  tearDown(() => database.close());

  test(
    'only completed OS export marks the encrypted snapshot as backed up',
    () async {
      expect(
        (await service.getFreshness()).freshness,
        BackupFreshness.neverExported,
      );
      filePicker.saved = false;
      expect(await service.exportToUserSelectedFile(password), isFalse);
      expect(
        (await service.getFreshness()).freshness,
        BackupFreshness.neverExported,
      );
      filePicker.saved = true;
      expect(await service.exportToUserSelectedFile(password), isTrue);
      expect(
        (await service.getFreshness()).freshness,
        BackupFreshness.noChanges,
      );
      expect(filePicker.name, matches(RegExp(r'^OnTime-.*\.ontimebackup$')));
      final preview = await service.previewEncryptedBackup(
        filePicker.bytes!,
        password,
      );
      expect(preview.preview.scheduleCount, 1);
      expect(
        utf8.decode(filePicker.bytes!, allowMalformed: true),
        isNot(contains('local note')),
      );
    },
  );

  test('failed OS export leaves backup freshness unchanged', () async {
    filePicker.error = StateError('storage unavailable');
    await expectLater(
      service.exportToUserSelectedFile(password),
      throwsStateError,
    );
    expect(
      (await service.getFreshness()).freshness,
      BackupFreshness.neverExported,
    );
  });

  test(
    'restore selection cancellation and preview never replace live data',
    () async {
      expect(await service.selectAndPreviewRestore(password), isNull);
      filePicker.bytes = await service.createEncryptedBackup(password);
      final candidate = await service.selectAndPreviewRestore(password);
      expect(candidate!.preview.scheduleCount, 1);
      expect(
        (await database.scheduleDao.getScheduleList()).single.schedule.id,
        'schedule-1',
      );
      filePicker.bytes = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        service.selectAndPreviewRestore(password),
        throwsA(isA<Exception>()),
      );
      expect(
        (await database.scheduleDao.getScheduleList()).single.schedule.id,
        'schedule-1',
      );
    },
  );

  test(
    'preview authenticates backup and restore replaces active data',
    () async {
      final encrypted = await service.createEncryptedBackup(password);

      await database.deleteAllDurableData();
      await database.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: 'replacement data',
        ),
      );

      final candidate = await service.previewEncryptedBackup(
        encrypted,
        password,
      );
      expect(candidate.preview.scheduleCount, 1);
      expect(candidate.preview.defaultPreparationStepCount, 1);

      await service.applyRestore(candidate);

      final restoredUser = (await database.userDao.getUserById(
        'local-profile',
      ))!;
      final restoredSchedules = await database.scheduleDao.getScheduleList();
      expect(restoredUser.note, 'local note');
      expect(restoredUser.scoreOrNull, 75);
      expect(restoredSchedules.single.schedule.id, 'schedule-1');
    },
  );

  test(
    'format 2 restores owned preparation and exclusions without regenerating deleted slots',
    () async {
      final recurring = RecurringScheduleRepositoryImpl(
        database,
        now: () => DateTime.utc(2030, 1, 1),
      );
      final schedule = _schedule().copyWith(
        id: 'series',
        scheduleTime: DateTime.utc(2030, 1, 2, 10),
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
      );
      final preparation = await database.preparationUserDao
          .getPreparationUsersByUserId('local-profile');
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: schedule.scheduleTime,
        timeZoneId: 'UTC',
        count: 3,
      );
      await recurring.create(schedule, preparation, rule);
      final generated = (await database.scheduleDao.getScheduleList())
          .map((r) => r.toScheduleEntity())
          .where((s) => s.isRecurring)
          .toList();
      final deleted = generated[1];
      await recurring.delete(deleted, RecurringEditScope.occurrence);
      final encrypted = await service.createEncryptedBackup(password);
      final candidate = await service.previewEncryptedBackup(
        encrypted,
        password,
      );
      await service.applyRestore(candidate);
      await recurring.materialize(DateTime.utc(2030), DateTime.utc(2031));
      final restored = (await database.scheduleDao.getScheduleList())
          .map((r) => r.toScheduleEntity())
          .where((s) => s.isRecurring)
          .toList();
      expect(restored, hasLength(2));
      expect(restored.any((s) => s.id == deleted.id), isFalse);
      expect(
        (await recurring.getPreparation(
          restored.first.preparationDefinitionId!,
        )).preparationStepList.single.preparationName,
        'Pack',
      );
    },
  );

  test(
    'format 1 remains importable and malformed new references never replace data',
    () async {
      final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
      final encrypted = await service.createEncryptedBackup(password);
      final json =
          jsonDecode(
                utf8.decode(
                  await crypto.decrypt(
                    container: encrypted,
                    password: password,
                  ),
                ),
              )
              as Map<String, dynamic>;
      json['formatVersion'] = 1;
      json.remove('recurring');
      for (final value in json['schedules'] as List) {
        for (final key in [
          'recurringSegmentId',
          'recurringSlotKey',
          'recurringOrdinal',
          'recurringOverrides',
          'preparationDefinitionId',
        ]) {
          (value as Map).remove(key);
        }
      }
      Future<Uint8List> encoded() => crypto.encrypt(
        plaintext: Uint8List.fromList(utf8.encode(jsonEncode(json))),
        password: password,
      );
      final old = await service.previewEncryptedBackup(
        await encoded(),
        password,
      );
      await service.applyRestore(old);
      expect(
        (await database.scheduleDao.getScheduleList()).single.schedule.id,
        'schedule-1',
      );
      json['formatVersion'] = 2;
      json['recurring'] = {
        'definitions': [],
        'steps': [],
        'segments': [],
        'exclusions': [],
      };
      (json['schedules'] as List).first['preparationDefinitionId'] = 'unknown';
      await expectLater(
        service.previewEncryptedBackup(await encoded(), password),
        throwsFormatException,
      );
      expect(
        (await database.scheduleDao.getScheduleList()).single.schedule.id,
        'schedule-1',
      );
    },
  );

  test('wrong password leaves current database unchanged', () async {
    final encrypted = await service.createEncryptedBackup(password);
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'must survive',
      ),
    );

    await expectLater(
      service.previewEncryptedBackup(encrypted, 'wrong backup password'),
      throwsFormatException,
    );

    expect(
      (await database.userDao.getUserById('local-profile'))!.note,
      'must survive',
    );
  });
}

ScheduleEntity _schedule() => ScheduleEntity(
  id: 'schedule-1',
  place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
  scheduleName: 'Meeting',
  timeZoneId: 'Asia/Seoul',
  occurrenceOffsetSeconds: 9 * 60 * 60,
  scheduleTime: DateTime(2026, 9, 2, 10),
  moveTime: const Duration(minutes: 20),
  isChanged: false,
  isStarted: false,
  scheduleSpareTime: const Duration(minutes: 5),
  scheduleNote: '',
);

class _MetadataProvider implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1.0.1', buildNumber: '1');
}

class _FilePicker extends BackupFilePicker {
  _FilePicker() : super(isIOS: true);
  bool saved = true;
  Object? error;
  Uint8List? bytes;
  String? name;

  @override
  Future<bool> save(Uint8List encrypted, String suggestedName) async {
    if (error != null) throw error!;
    bytes = encrypted;
    name = suggestedName;
    return saved;
  }

  @override
  Future<Uint8List?> select() async => bytes;
}
