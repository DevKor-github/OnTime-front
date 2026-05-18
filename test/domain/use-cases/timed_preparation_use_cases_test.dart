import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_with_time_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:on_time_front/domain/use-cases/clear_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/clear_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_nearest_upcoming_schedule_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_timed_preparation_snapshot_use_case.dart';
import 'package:on_time_front/domain/use-cases/create_custom_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_adjacent_schedule_with_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_by_date_use_case.dart';
import 'package:on_time_front/domain/use-cases/load_schedules_for_week_use_case.dart';
import 'package:on_time_front/domain/use-cases/mark_early_start_session_use_case.dart';
import 'package:on_time_front/domain/use-cases/save_timed_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_preparations_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_preparation_by_schedule_id_use_case.dart';
import 'package:on_time_front/domain/use-cases/update_spare_time_use_case.dart';

void main() {
  test('SaveTimedPreparationUseCase stores a fingerprinted snapshot', () async {
    final repository = _FakeTimedPreparationRepository();
    final useCase = SaveTimedPreparationUseCase(repository);
    final schedule = _scheduleWithPreparation('schedule-1');
    final preparation = schedule.preparation.timeElapsed(
      const Duration(minutes: 3),
    );
    final savedAt = DateTime.utc(2026, 5, 15, 8);

    await useCase(schedule, preparation, savedAt: savedAt);

    expect(repository.savedScheduleId, 'schedule-1');
    expect(repository.savedSnapshot!.preparation, preparation);
    expect(repository.savedSnapshot!.savedAt, savedAt);
    expect(
      repository.savedSnapshot!.scheduleFingerprint,
      schedule.cacheFingerprint,
    );
  });

  test(
    'timed preparation read and clear use cases delegate by schedule id',
    () async {
      final repository = _FakeTimedPreparationRepository();
      final snapshot = TimedPreparationSnapshotEntity(
        preparation: _scheduleWithPreparation('schedule-1').preparation,
        savedAt: DateTime.utc(2026, 5, 15, 8),
        scheduleFingerprint: 'fingerprint-1',
      );
      repository.savedSnapshot = snapshot;

      expect(
        await GetTimedPreparationSnapshotUseCase(repository)('schedule-1'),
        snapshot,
      );
      await ClearTimedPreparationUseCase(repository)('schedule-1');

      expect(repository.loadedScheduleIds, ['schedule-1']);
      expect(repository.clearedScheduleIds, ['schedule-1']);
    },
  );

  test(
    'early start session use cases mark read and clear one schedule',
    () async {
      final repository = _FakeEarlyStartSessionRepository();
      final startedAt = DateTime.utc(2026, 5, 15, 8);

      await MarkEarlyStartSessionUseCase(repository)(
        scheduleId: 'schedule-1',
        startedAt: startedAt,
      );
      final session = await GetEarlyStartSessionUseCase(repository)(
        'schedule-1',
      );
      await ClearEarlyStartSessionUseCase(repository)('schedule-1');

      expect(
        session,
        EarlyStartSessionEntity(scheduleId: 'schedule-1', startedAt: startedAt),
      );
      expect(repository.markedSessions, [('schedule-1', startedAt)]);
      expect(repository.loadedScheduleIds, ['schedule-1']);
      expect(repository.clearedScheduleIds, ['schedule-1']);
    },
  );

  test('timed preparation snapshots copy changed cache fields', () {
    final original = TimedPreparationSnapshotEntity(
      preparation: _scheduleWithPreparation('schedule-1').preparation,
      savedAt: DateTime.utc(2026, 5, 15, 8),
      scheduleFingerprint: 'fingerprint-1',
    );
    final replacementPreparation = _scheduleWithPreparation(
      'schedule-2',
    ).preparation.timeElapsed(const Duration(minutes: 10));
    final replacementSavedAt = DateTime.utc(2026, 5, 15, 9);

    final copied = original.copyWith(
      preparation: replacementPreparation,
      savedAt: replacementSavedAt,
      scheduleFingerprint: 'fingerprint-2',
    );

    expect(copied.preparation, replacementPreparation);
    expect(copied.savedAt, replacementSavedAt);
    expect(copied.scheduleFingerprint, 'fingerprint-2');
    expect(original.copyWith().props, [
      original.preparation,
      original.savedAt,
      'fingerprint-1',
    ]);
  });

  test(
    'LoadAdjacentScheduleWithPreparationUseCase loads each schedule prep',
    () async {
      final scheduleRepository = _FakeScheduleRepository({
        _schedule('outside-before', DateTime.utc(2026, 5, 14, 23)),
        _schedule('schedule-b', DateTime.utc(2026, 5, 15, 11)),
        _schedule('schedule-a', DateTime.utc(2026, 5, 15, 9)),
        _schedule('outside-after', DateTime.utc(2026, 5, 16)),
      });
      final preparationRepository = _FakePreparationRepository();
      final useCase = LoadAdjacentScheduleWithPreparationUseCase(
        LoadSchedulesByDateUseCase(scheduleRepository),
        GetSchedulesByDateUseCase(scheduleRepository),
        LoadPreparationByScheduleIdUseCase(preparationRepository),
      );
      final start = DateTime.utc(2026, 5, 15);
      final end = DateTime.utc(2026, 5, 16);

      await useCase(startDate: start, endDate: end);

      expect(scheduleRepository.requestedRanges.single, (start, end));
      expect(preparationRepository.loadedScheduleIds, [
        'schedule-a',
        'schedule-b',
      ]);
    },
  );

  test(
    'GetPreparationByScheduleIdUseCase waits for matching cache entry',
    () async {
      final preparationRepository = _FakePreparationRepository();
      final useCase = GetPreparationByScheduleIdUseCase(preparationRepository);

      final future = useCase('schedule-1');
      preparationRepository.emit({
        'other': const PreparationEntity(preparationStepList: []),
      });
      preparationRepository.emit({
        'schedule-1': const PreparationEntity(
          preparationStepList: [
            PreparationStepEntity(
              id: 'prep-1',
              preparationName: 'Pack',
              preparationTime: Duration(minutes: 5),
            ),
          ],
        ),
      });

      final preparation = await future;

      expect(preparation.preparationStepList.single.id, 'prep-1');
    },
  );

  test(
    'preparation use cases delegate to repository with explicit arguments',
    () async {
      final repository = _FakePreparationRepository();
      final preparation = _preparation('prep-1');

      await CreateCustomPreparationUseCase(repository)(
        preparation,
        'schedule-1',
      );
      await UpdateDefaultPreparationUseCase(repository)(preparation);
      await UpdatePreparationByScheduleIdUseCase(repository)(
        preparation,
        'schedule-2',
      );
      await UpdateSpareTimeUseCase(repository)(const Duration(minutes: 20));

      expect(repository.customPreparationCalls, [(preparation, 'schedule-1')]);
      expect(repository.updatedDefaultPreparations, [preparation]);
      expect(repository.updatedSchedulePreparations, [
        (preparation, 'schedule-2'),
      ]);
      expect(repository.updatedSpareTimes, [const Duration(minutes: 20)]);
    },
  );

  test(
    'default and stream preparation use cases expose repository values',
    () async {
      final repository = _FakePreparationRepository();
      final defaultPreparation = _preparation('default-prep');
      final schedulePreparation = _preparation('schedule-prep');
      repository.defaultPreparation = defaultPreparation;
      repository.emit({'schedule-1': schedulePreparation});

      expect(
        await GetDefaultPreparationUseCase(repository)(),
        defaultPreparation,
      );
      expect(await StreamPreparationsUseCase(repository)().first, {
        'schedule-1': schedulePreparation,
      });
    },
  );

  test(
    'GetNearestUpcomingScheduleUseCase loads prep for nearest active schedule',
    () async {
      final now = DateTime.now();
      final nearest = _schedule('nearest', now.add(const Duration(hours: 1)));
      final ended = _schedule(
        'ended',
        now.add(const Duration(minutes: 30)),
      ).copyWith(doneStatus: ScheduleDoneStatus.normalEnd);
      final later = _schedule('later', now.add(const Duration(hours: 2)));
      final scheduleRepository = _FakeScheduleRepository({
        later,
        ended,
        nearest,
      });
      final preparationRepository = _FakePreparationRepository()
        ..emit({
          'nearest': const PreparationEntity(
            preparationStepList: [
              PreparationStepEntity(
                id: 'prep-1',
                preparationName: 'Pack',
                preparationTime: Duration(minutes: 5),
              ),
            ],
          ),
        });
      final loadSchedulesByDate = LoadSchedulesByDateUseCase(
        scheduleRepository,
      );
      final useCase = GetNearestUpcomingScheduleUseCase(
        GetSchedulesByDateUseCase(scheduleRepository),
        LoadPreparationByScheduleIdUseCase(preparationRepository),
        GetPreparationByScheduleIdUseCase(preparationRepository),
        LoadSchedulesForWeekUseCase(loadSchedulesByDate),
      );

      final schedule = await useCase().first;

      expect(schedule!.id, 'nearest');
      expect(preparationRepository.loadedScheduleIds, ['nearest']);
      expect(schedule.preparation.preparationStepList.single.id, 'prep-1');
      expect(
        scheduleRepository.requestedRanges.length,
        greaterThanOrEqualTo(1),
      );
    },
  );
}

class _FakeTimedPreparationRepository implements TimedPreparationRepository {
  String? savedScheduleId;
  TimedPreparationSnapshotEntity? savedSnapshot;
  final loadedScheduleIds = <String>[];
  final clearedScheduleIds = <String>[];

  @override
  Future<void> clearTimedPreparation(String scheduleId) async {
    clearedScheduleIds.add(scheduleId);
  }

  @override
  Future<TimedPreparationSnapshotEntity?> getTimedPreparationSnapshot(
    String scheduleId,
  ) async {
    loadedScheduleIds.add(scheduleId);
    return savedSnapshot;
  }

  @override
  Future<void> saveTimedPreparationSnapshot(
    String scheduleId,
    TimedPreparationSnapshotEntity snapshot,
  ) async {
    savedScheduleId = scheduleId;
    savedSnapshot = snapshot;
  }
}

class _FakeEarlyStartSessionRepository implements EarlyStartSessionRepository {
  final markedSessions = <(String, DateTime)>[];
  final loadedScheduleIds = <String>[];
  final clearedScheduleIds = <String>[];
  final sessions = <String, EarlyStartSessionEntity>{};

  @override
  Future<void> markStarted({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    markedSessions.add((scheduleId, startedAt));
    sessions[scheduleId] = EarlyStartSessionEntity(
      scheduleId: scheduleId,
      startedAt: startedAt,
    );
  }

  @override
  Future<EarlyStartSessionEntity?> getSession(String scheduleId) async {
    loadedScheduleIds.add(scheduleId);
    return sessions[scheduleId];
  }

  @override
  Future<void> clear(String scheduleId) async {
    clearedScheduleIds.add(scheduleId);
    sessions.remove(scheduleId);
  }
}

class _FakeScheduleRepository implements ScheduleRepository {
  _FakeScheduleRepository(this._schedules);

  final Set<ScheduleEntity> _schedules;
  final requestedRanges = <(DateTime, DateTime?)>[];

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream => Stream.value(_schedules);

  @override
  Future<void> createSchedule(ScheduleEntity schedule) async {}

  @override
  Future<void> deleteSchedule(ScheduleEntity schedule) async {}

  @override
  Future<void> finishSchedule(String scheduleId, int latenessTime) async {}

  @override
  Future<ScheduleEntity> getScheduleById(String id) async =>
      _schedules.firstWhere((schedule) => schedule.id == id);

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    requestedRanges.add((startDate, endDate));
    return _schedules.toList();
  }

  @override
  Future<void> updateSchedule(ScheduleEntity schedule) async {}
}

class _FakePreparationRepository implements PreparationRepository {
  final _controller =
      StreamController<Map<String, PreparationEntity>>.broadcast();
  Map<String, PreparationEntity> _currentPreparations = {};
  PreparationEntity defaultPreparation = const PreparationEntity(
    preparationStepList: [],
  );
  final loadedScheduleIds = <String>[];
  final customPreparationCalls = <(PreparationEntity, String)>[];
  final updatedDefaultPreparations = <PreparationEntity>[];
  final updatedSchedulePreparations = <(PreparationEntity, String)>[];
  final updatedSpareTimes = <Duration>[];

  @override
  Stream<Map<String, PreparationEntity>> get preparationStream async* {
    yield _currentPreparations;
    yield* _controller.stream;
  }

  void emit(Map<String, PreparationEntity> preparations) {
    _currentPreparations = preparations;
    _controller.add(preparations);
  }

  @override
  Future<void> createCustomPreparation(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    customPreparationCalls.add((preparationEntity, scheduleId));
  }

  @override
  Future<void> createDefaultPreparation({
    required PreparationEntity preparationEntity,
    required Duration spareTime,
    required String note,
  }) async {}

  @override
  Future<PreparationEntity> getDefualtPreparation() async => defaultPreparation;

  @override
  Future<void> getPreparationByScheduleId(String scheduleId) async {
    loadedScheduleIds.add(scheduleId);
  }

  @override
  Future<void> updateDefaultPreparation(
    PreparationEntity preparationEntity,
  ) async {
    updatedDefaultPreparations.add(preparationEntity);
  }

  @override
  Future<void> updatePreparationByScheduleId(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    updatedSchedulePreparations.add((preparationEntity, scheduleId));
  }

  @override
  Future<void> updateSpareTime(Duration newSpareTime) async {
    updatedSpareTimes.add(newSpareTime);
  }
}

PreparationEntity _preparation(String id) {
  return PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: id,
        preparationName: 'Pack',
        preparationTime: const Duration(minutes: 5),
      ),
    ],
  );
}

ScheduleEntity _schedule(String id, DateTime scheduleTime) {
  return ScheduleEntity(
    id: id,
    place: const PlaceEntity(id: 'place-1', placeName: 'Office'),
    scheduleName: 'Meeting',
    scheduleTime: scheduleTime,
    moveTime: const Duration(minutes: 10),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 5),
    scheduleNote: '',
  );
}

ScheduleWithPreparationEntity _scheduleWithPreparation(String id) {
  final schedule = _schedule(id, DateTime.utc(2026, 5, 15, 9));
  return ScheduleWithPreparationEntity(
    id: schedule.id,
    place: schedule.place,
    scheduleName: schedule.scheduleName,
    scheduleTime: schedule.scheduleTime,
    moveTime: schedule.moveTime,
    isChanged: schedule.isChanged,
    isStarted: schedule.isStarted,
    scheduleSpareTime: schedule.scheduleSpareTime,
    scheduleNote: schedule.scheduleNote,
    preparation: const PreparationWithTimeEntity(
      preparationStepList: [
        PreparationStepWithTimeEntity(
          id: 'prep-1',
          preparationName: 'Pack',
          preparationTime: Duration(minutes: 10),
          nextPreparationId: null,
        ),
      ],
    ),
  );
}
