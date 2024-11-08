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
              await preparationLocalDataSource.updatePreparation(step);
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

      final localPreparationEntity = preparationLocalDataSource
          .getPreparationByScheduleId(preparationStepId);

      final remotePreparationEntity = preparationRemoteDataSource
          .getPreparationByScheduleId(preparationStepId);

      bool isFirstResponse = true;

      localPreparationEntity.then((localPreparationEntity) {
        if (isFirstResponse) {
          isFirstResponse = false;
          for (final step in localPreparationEntity.preparationStepList) {
            streamController.add(step);
          }
        }
      });

      remotePreparationEntity.then((remotePreparationEntity) async {
        if (isFirstResponse) {
          isFirstResponse = false;
          for (final step in remotePreparationEntity.preparationStepList) {
            streamController.add(step);
          }
        } else {
          if (localPreparationEntity != remotePreparationEntity) {
            for (final step in remotePreparationEntity.preparationStepList) {
              streamController.add(step);
              await preparationLocalDataSource.updatePreparation(step);
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
  Future<void> updatePreparation(
      PreparationStepEntity preparationEntity) async {
    try {
      await preparationRemoteDataSource.updatePreparation(preparationEntity);
      await preparationLocalDataSource.updatePreparation(preparationEntity);
    } catch (e) {
      rethrow;
    }
  }
}
