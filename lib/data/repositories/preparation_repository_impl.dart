import 'dart:async';

import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

import 'package:on_time_front/domain/repositories/preparation_repository.dart';

class PreparationRepositoryImpl implements PreparationRepository {
  final PreparationRemoteDataSource preparationRemoteDataSource;
  final PreparationLocalDataSource preparationLocalDataSource;

  PreparationRepositoryImpl({
    required this.preparationRemoteDataSource,
    required this.preparationLocalDataSource,
  });

  @override
  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity, String userId) async {
    try {
      await preparationRemoteDataSource.createDefaultPreparation(
          preparationEntity, userId);
      await preparationLocalDataSource.createDefaultPreparation(
          preparationEntity, userId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId) async {
    try {
      await preparationRemoteDataSource.createCustomPreparation(
          preparationEntity, scheduleId);
      await preparationLocalDataSource.createCustomPreparation(
          preparationEntity, scheduleId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deletePreparation(PreparationEntity preparationEntity) async {
    try {
      await preparationRemoteDataSource.deletePreparation(preparationEntity);
      await preparationLocalDataSource.deletePreparation(preparationEntity);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<PreparationEntity> getPreparationByScheduleId(
      String scheduleId) async* {
    try {
      final streamController = StreamController<PreparationEntity>();

      final localPreparationEntity =
          preparationLocalDataSource.getPreparationByScheduleId(scheduleId);

      final remotePreparationEntity =
          preparationRemoteDataSource.getPreparationByScheduleId(scheduleId);

      bool isFirstResponse = true;

      localPreparationEntity.then((localPreparationEntity) {
        if (isFirstResponse) {
          isFirstResponse = false;
          streamController.add(localPreparationEntity);
        }
      });

      remotePreparationEntity.then((remotePreparationEntity) async {
        if (isFirstResponse) {
          isFirstResponse = false;
          streamController.add(remotePreparationEntity);
        } else {
          if (localPreparationEntity != remotePreparationEntity) {
            streamController.add(remotePreparationEntity);
            for (final step in remotePreparationEntity.preparationStepList) {
              await preparationLocalDataSource.updatePreparationStep(step);
            }
          }
        }
      });

      yield* streamController.stream;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) async* {
    try {
      final streamController = StreamController<PreparationStepEntity>();

      final localPreparationStep =
          preparationLocalDataSource.getPreparationStepById(preparationStepId);

      final remotePreparationStep =
          preparationRemoteDataSource.getPreparationStepById(preparationStepId);

      bool isFirstResponse = true;

      localPreparationStep.then((localStep) {
        if (isFirstResponse) {
          isFirstResponse = false;
          streamController.add(localStep);
        }
      });

      remotePreparationStep.then((remoteStep) async {
        if (isFirstResponse) {
          isFirstResponse = false;
          streamController.add(remoteStep);
        } else {
          final localStep = await localPreparationStep;
          if (localStep != remoteStep) {
            streamController.add(remoteStep);
            await preparationLocalDataSource.updatePreparationStep(remoteStep);
          }
        }
      });

      yield* streamController.stream;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePreparationStep(
      PreparationStepEntity preparationEntity) async {
    try {
      await preparationRemoteDataSource
          .updatePreparationStep(preparationEntity);
      await preparationLocalDataSource.updatePreparationStep(preparationEntity);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePreparationByScheduleId(
      PreparationEntity preparationEntity, String scheduleId) async {
    try {
      await preparationRemoteDataSource.updateCustomPreparation(
          preparationEntity, scheduleId);
      await preparationLocalDataSource.updateCustomPreparation(
          preparationEntity, scheduleId);
    } catch (e) {
      rethrow;
    }
  }
}
