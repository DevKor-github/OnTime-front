import 'package:drift/native.dart';
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
  const password = 'portable backup password';
  late AppDatabase database;
  late BackupService service;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    service = BackupService(
      database,
      _MetadataProvider(),
      crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
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
    await database.scheduleDao.createSchedule(_schedule().toScheduleWithPlaceRow());
  });

  tearDown(() => database.close());

  test('preview authenticates backup and restore replaces active data', () async {
    final encrypted = await service.createEncryptedBackup(password);

    await database.deleteAllDurableData();
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: 'replacement data',
      ),
    );

    final candidate = await service.previewEncryptedBackup(encrypted, password);
    expect(candidate.preview.scheduleCount, 1);
    expect(candidate.preview.defaultPreparationStepCount, 1);

    await service.applyRestore(candidate);

    final restoredUser = (await database.userDao.getUserById('local-profile'))!;
    final restoredSchedules = await database.scheduleDao.getScheduleList();
    expect(restoredUser.note, 'local note');
    expect(restoredUser.scoreOrNull, 75);
    expect(restoredSchedules.single.schedule.id, 'schedule-1');
  });

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
