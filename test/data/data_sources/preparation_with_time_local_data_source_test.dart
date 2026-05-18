import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/data/repositories/timed_preparation_repository_impl.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreparationWithTimeLocalDataSourceImpl dataSource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dataSource = PreparationWithTimeLocalDataSourceImpl();
  });

  test('savePreparation persists elapsed step state for a schedule', () async {
    final snapshot = _snapshot();

    await dataSource.savePreparation('schedule-1', snapshot);

    final loaded = await dataSource.loadPreparation('schedule-1');

    expect(loaded, snapshot);
    expect(loaded!.preparation.currentStep?.id, 'step-2');
    expect(loaded.preparation.stepElapsedTimesInSeconds, [600, 120]);
  });

  test(
    'loadPreparation returns null for missing or corrupt snapshots',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preparation_with_time_corrupt', '{not json');

      expect(await dataSource.loadPreparation('missing'), isNull);
      expect(await dataSource.loadPreparation('corrupt'), isNull);
    },
  );

  test(
    'loadPreparation supports legacy snapshots without savedAt or fingerprint',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preparation_with_time_legacy', '''
      {
        "steps": [
          {
            "id": "step-1",
            "name": "Pack",
            "time": 600000,
            "nextId": null,
            "elapsed": 600000
          }
        ]
      }
      ''');

      final loaded = await dataSource.loadPreparation('legacy');

      expect(loaded, isNotNull);
      expect(loaded!.scheduleFingerprint, '');
      expect(loaded.preparation.preparationStepList.single.isDone, isFalse);
      expect(
        loaded.preparation.preparationStepList.single.elapsedTime,
        const Duration(minutes: 10),
      );
    },
  );

  test(
    'clearPreparation removes only the requested schedule snapshot',
    () async {
      await dataSource.savePreparation('schedule-1', _snapshot());
      await dataSource.savePreparation(
        'schedule-2',
        _snapshot(scheduleFingerprint: 'other-fingerprint'),
      );

      await dataSource.clearPreparation('schedule-1');

      expect(await dataSource.loadPreparation('schedule-1'), isNull);
      expect(
        (await dataSource.loadPreparation('schedule-2'))!.scheduleFingerprint,
        'other-fingerprint',
      );
    },
  );

  test(
    'TimedPreparationRepositoryImpl delegates cache lifecycle operations',
    () async {
      final repository = TimedPreparationRepositoryImpl(
        localDataSource: dataSource,
      );
      final snapshot = _snapshot();

      await repository.saveTimedPreparationSnapshot('schedule-1', snapshot);
      expect(
        await repository.getTimedPreparationSnapshot('schedule-1'),
        snapshot,
      );

      await repository.clearTimedPreparation('schedule-1');
      expect(
        await repository.getTimedPreparationSnapshot('schedule-1'),
        isNull,
      );
    },
  );
}

TimedPreparationSnapshotEntity _snapshot({
  String scheduleFingerprint = 'fingerprint',
}) {
  return TimedPreparationSnapshotEntity(
    savedAt: DateTime.fromMillisecondsSinceEpoch(1778774400000),
    scheduleFingerprint: scheduleFingerprint,
    preparation: const PreparationWithTimeEntity(
      preparationStepList: [
        PreparationStepWithTimeEntity(
          id: 'step-1',
          preparationName: 'Pack',
          preparationTime: Duration(minutes: 10),
          nextPreparationId: 'step-2',
          elapsedTime: Duration(minutes: 10),
          isDone: true,
        ),
        PreparationStepWithTimeEntity(
          id: 'step-2',
          preparationName: 'Dress',
          preparationTime: Duration(minutes: 5),
          nextPreparationId: null,
          elapsedTime: Duration(minutes: 2),
          isDone: false,
        ),
      ],
    ),
  );
}
