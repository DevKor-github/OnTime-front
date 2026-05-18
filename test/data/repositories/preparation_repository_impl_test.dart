import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';
import 'package:on_time_front/data/models/create_defualt_preparation_request_model.dart';
import 'package:on_time_front/data/repositories/preparation_repository_impl.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

void main() {
  late _FakePreparationRemoteDataSource remoteDataSource;
  late PreparationRepositoryImpl repository;

  setUp(() {
    remoteDataSource = _FakePreparationRemoteDataSource();
    repository = PreparationRepositoryImpl(
      preparationRemoteDataSource: remoteDataSource,
      preparationLocalDataSource: _FakePreparationLocalDataSource(),
    );
  });

  test(
    'preparation stream starts empty and updates after custom create',
    () async {
      expect(await repository.preparationStream.first, isEmpty);

      await repository.createCustomPreparation(
        _preparation('step-1'),
        'schedule-1',
      );

      expect(remoteDataSource.createdCustomSchedules, ['schedule-1']);
      expect(await repository.preparationStream.first, {
        'schedule-1': _preparation('step-1'),
      });
    },
  );

  test(
    'remote schedule preparation load publishes the fetched preparation',
    () async {
      remoteDataSource.preparationsByScheduleId['schedule-1'] = _preparation(
        'remote-step',
      );

      await repository.getPreparationByScheduleId('schedule-1');

      expect(await repository.preparationStream.first, {
        'schedule-1': _preparation('remote-step'),
      });
    },
  );

  test(
    'schedule preparation update publishes the edited preparation',
    () async {
      await repository.updatePreparationByScheduleId(
        _preparation('updated-step'),
        'schedule-1',
      );

      expect(remoteDataSource.updatedScheduleIds, ['schedule-1']);
      expect(await repository.preparationStream.first, {
        'schedule-1': _preparation('updated-step'),
      });
    },
  );

  test(
    'default preparation and spare time calls delegate to remote source',
    () async {
      remoteDataSource.defaultPreparation = _preparation('default-step');

      await repository.createDefaultPreparation(
        preparationEntity: _preparation('default-step'),
        spareTime: const Duration(minutes: 5),
        note: 'note',
      );
      final defaultPreparation = await repository.getDefualtPreparation();
      await repository.updateDefaultPreparation(_preparation('default-step'));
      await repository.updateSpareTime(const Duration(minutes: 15));

      expect(defaultPreparation, _preparation('default-step'));
      expect(remoteDataSource.createdDefaultModels, hasLength(1));
      expect(remoteDataSource.updatedDefaultPreparations, [
        _preparation('default-step'),
      ]);
      expect(remoteDataSource.updatedSpareTimes, [const Duration(minutes: 15)]);
    },
  );

  test(
    'remote failures are surfaced to callers without stream mutation',
    () async {
      remoteDataSource.throwOnNext = true;

      await expectLater(
        repository.createCustomPreparation(
          _preparation('step-1'),
          'schedule-1',
        ),
        throwsException,
      );

      expect(await repository.preparationStream.first, isEmpty);
    },
  );
}

PreparationEntity _preparation(String stepId) {
  return PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: stepId,
        preparationName: stepId,
        preparationTime: const Duration(minutes: 10),
      ),
    ],
  );
}

class _FakePreparationRemoteDataSource implements PreparationRemoteDataSource {
  final createdDefaultModels = <CreateDefaultPreparationRequestModel>[];
  final createdCustomSchedules = <String>[];
  final updatedDefaultPreparations = <PreparationEntity>[];
  final updatedScheduleIds = <String>[];
  final updatedSpareTimes = <Duration>[];
  final preparationsByScheduleId = <String, PreparationEntity>{};
  PreparationEntity defaultPreparation = _preparation('default');
  bool throwOnNext = false;

  void _maybeThrow() {
    if (throwOnNext) {
      throwOnNext = false;
      throw Exception('remote failed');
    }
  }

  @override
  Future<void> createDefaultPreparation(
    CreateDefaultPreparationRequestModel model,
  ) async {
    _maybeThrow();
    createdDefaultModels.add(model);
  }

  @override
  Future<void> createCustomPreparation(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    _maybeThrow();
    createdCustomSchedules.add(scheduleId);
  }

  @override
  Future<PreparationEntity> getPreparationByScheduleId(
    String scheduleId,
  ) async {
    _maybeThrow();
    return preparationsByScheduleId[scheduleId] ?? _preparation('missing');
  }

  @override
  Future<PreparationEntity> getDefualtPreparation() async {
    _maybeThrow();
    return defaultPreparation;
  }

  @override
  Future<void> updateDefaultPreparation(
    PreparationEntity preparationEntity,
  ) async {
    _maybeThrow();
    updatedDefaultPreparations.add(preparationEntity);
  }

  @override
  Future<void> updatePreparationByScheduleId(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    _maybeThrow();
    updatedScheduleIds.add(scheduleId);
  }

  @override
  Future<void> updateSpareTime(Duration newSpareTime) async {
    _maybeThrow();
    updatedSpareTimes.add(newSpareTime);
  }
}

class _FakePreparationLocalDataSource implements PreparationLocalDataSource {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
