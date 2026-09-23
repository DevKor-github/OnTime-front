import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/data/repositories/timed_preparation_repository_impl.dart';
import 'package:on_time_front/domain/entities/preparation_action_event_entity.dart';
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

    expect(loaded!.contentOmitted, isTrue);
    expect(loaded.scheduleFingerprint, snapshot.scheduleFingerprint);
    final raw = (await SharedPreferences.getInstance()).getString(
      'preparation_with_time_schedule-1',
    )!;
    expect(raw, isNot(contains('Pack')));
    expect(raw, isNot(contains('Dress')));
    expect(raw, isNot(contains('nextId')));
    expect(loaded.preparation.stepElapsedTimesInSeconds, [600, 120]);
  });

  test('savePreparation persists preparation run action events', () async {
    final startedAt = DateTime(2026, 5, 15, 8);
    final skipAt = startedAt.add(const Duration(minutes: 3));
    final snapshot = _snapshot(
      startedAt: startedAt,
      actionEvents: [
        PreparationActionEventEntity.skipStep(
          stepId: 'step-1',
          occurredAt: skipAt,
        ),
      ],
    );

    await dataSource.savePreparation('schedule-1', snapshot);

    final loaded = await dataSource.loadPreparation('schedule-1');

    expect(loaded!.startedAt, startedAt);
    expect(loaded.actionEvents, snapshot.actionEvents);
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

  test('loadPreparation rejects unverifiable legacy snapshots', () async {
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

    expect(loaded, isNull);
  });

  test('clearPreparation removes only the requested schedule snapshot', () async {
    await dataSource.savePreparation('schedule-1', _snapshot());
    await dataSource.savePreparation(
      'schedule-2',
      _snapshot(
        scheduleFingerprint:
            'v2:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
    );

    await dataSource.clearPreparation('schedule-1');

    expect(await dataSource.loadPreparation('schedule-1'), isNull);
    expect(
      (await dataSource.loadPreparation('schedule-2'))!.scheduleFingerprint,
      'v2:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
  });

  test(
    'explicit malformed events and negative progress invalidate whole snapshot',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await dataSource.savePreparation('schedule-1', _snapshot());
      final baseline =
          jsonDecode(prefs.getString('preparation_with_time_schedule-1')!)
              as Map<String, dynamic>;
      for (final invalid in [
        null,
        'invalid',
        [42],
        [
          {'type': 'unknown', 'occurredAt': 1},
        ],
        [
          {'type': 'skipStep', 'occurredAt': 1},
        ],
        [
          {'type': 'skipStep', 'occurredAt': 1, 'stepId': 42},
        ],
        [
          {'type': 'skipStep', 'occurredAt': 1.2, 'stepId': 'step-1'},
        ],
      ]) {
        await prefs.setString(
          'preparation_with_time_schedule-1',
          jsonEncode({...baseline, 'actionEvents': invalid}),
        );
        expect(await dataSource.loadPreparation('schedule-1'), isNull);
      }
      final negative = jsonDecode(jsonEncode(baseline)) as Map<String, dynamic>;
      (negative['steps'] as List).first['elapsed'] = -1;
      await prefs.setString(
        'preparation_with_time_schedule-1',
        jsonEncode(negative),
      );
      expect(await dataSource.loadPreparation('schedule-1'), isNull);
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
        isA<TimedPreparationSnapshotEntity>().having(
          (value) => value.contentOmitted,
          'content omitted',
          true,
        ),
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
  String scheduleFingerprint =
      'v2:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  DateTime? startedAt,
  List<PreparationActionEventEntity> actionEvents = const [],
}) {
  return TimedPreparationSnapshotEntity(
    savedAt: DateTime.fromMillisecondsSinceEpoch(1778774400000),
    scheduleFingerprint: scheduleFingerprint,
    startedAt: startedAt,
    actionEvents: actionEvents,
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
