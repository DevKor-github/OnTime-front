import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Singleton(as: PreparationRepository)
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
  Future<PreparationEntity> deletePreparation(
      PreparationEntity preparationEntity) async {
    try {
      final updatedPreparation =
          await preparationLocalDataSource.deletePreparation(preparationEntity);
      return updatedPreparation;
    } catch (e) {
      throw Exception('Failed to delete preparation: $e');
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
            await preparationLocalDataSource.updatePreparation(remoteStep);
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
