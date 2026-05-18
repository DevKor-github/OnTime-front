import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

void main() {
  late AppDatabase database;
  late PreparationLocalDataSourceImpl dataSource;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customStatement('PRAGMA foreign_keys = ON');
    dataSource = PreparationLocalDataSourceImpl(appDatabase: database);

    await database
        .into(database.users)
        .insert(
          UsersCompanion(
            id: const drift.Value('userId'),
            email: const drift.Value('user@example.com'),
            name: const drift.Value('User'),
            spareTime: drift.Value(const Duration(minutes: 10).inSeconds),
            note: const drift.Value('note'),
            score: const drift.Value(4.5),
          ),
        );
    await database
        .into(database.places)
        .insert(
          const PlacesCompanion(
            id: drift.Value('place-1'),
            placeName: drift.Value('Office'),
          ),
        );
    await database
        .into(database.schedules)
        .insert(
          SchedulesCompanion(
            id: const drift.Value('scheduleId'),
            placeId: const drift.Value('place-1'),
            scheduleName: const drift.Value('Meeting'),
            scheduleTime: drift.Value(DateTime(2026, 5, 15, 9)),
            moveTime: const drift.Value(Duration(minutes: 15)),
            isChanged: const drift.Value(false),
            isStarted: const drift.Value(false),
            scheduleSpareTime: const drift.Value(Duration(minutes: 5)),
            scheduleNote: const drift.Value('note'),
            latenessTime: const drift.Value(0),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('creates and updates the default user preparation', () async {
    await dataSource.createDefaultPreparation(_preparation(userBased: true));

    final updated = const PreparationStepEntity(
      id: 'step-1',
      preparationName: 'Updated shower',
      preparationTime: Duration(minutes: 12),
    );
    await dataSource.updatePreparation(updated);

    final stored = await database.preparationUserDao
        .getPreparationUsersByUserId('userId');
    expect(stored.preparationStepList.single, updated);
  });

  test(
    'creates, reads, updates, and deletes custom schedule preparation',
    () async {
      await dataSource.createCustomPreparation(
        _preparation(userBased: false),
        'scheduleId',
      );

      final bySchedule = await dataSource.getPreparationByScheduleId(
        'scheduleId',
      );
      expect(bySchedule.preparationStepList.map((step) => step.id), [
        'step-1',
        'step-2',
      ]);
      expect(
        await dataSource.getPreparationStepById('step-1'),
        bySchedule.preparationStepList.first,
      );

      final updated = const PreparationStepEntity(
        id: 'step-1',
        preparationName: 'Updated schedule prep',
        preparationTime: Duration(minutes: 20),
        nextPreparationId: 'step-2',
      );
      await dataSource.updatePreparation(updated);
      expect(
        (await dataSource.getPreparationStepById('step-1')).preparationName,
        'Updated schedule prep',
      );

      final afterDelete = await dataSource.deletePreparation(
        PreparationEntity(preparationStepList: [updated]),
      );
      expect(afterDelete.preparationStepList.single.id, 'step-2');
    },
  );

  test('deletePreparation rejects empty preparation entities', () async {
    await expectLater(
      dataSource.deletePreparation(
        const PreparationEntity(preparationStepList: []),
      ),
      throwsException,
    );
  });
}

PreparationEntity _preparation({required bool userBased}) {
  if (!userBased) {
    return const PreparationEntity(
      preparationStepList: [
        PreparationStepEntity(
          id: 'step-1',
          preparationName: 'Shower',
          preparationTime: Duration(minutes: 10),
        ),
        PreparationStepEntity(
          id: 'step-2',
          preparationName: 'Pack',
          preparationTime: Duration(minutes: 5),
        ),
      ],
    );
  }

  return PreparationEntity(
    preparationStepList: [
      const PreparationStepEntity(
        id: 'step-1',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 10),
      ),
    ],
  );
}
