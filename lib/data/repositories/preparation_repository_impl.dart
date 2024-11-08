import 'dart:async';

import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

import 'package:on_time_front/domain/repositories/preparation_repository.dart';

class PreparationRepositoryImpl implements PreparationRepository {
  final PreparationRemoteDataSource remoteDataSource;
  final PreparationLocalDataSource localDataSource;

  PreparationRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Stream<PreparationEntity> getPreparationByScheduleId(String scheduleId) {
    return localDataSource.getPreparationByScheduleId(scheduleId);
  }

  @override
  Stream<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) {
    return localDataSource.getPreparationStepById(preparationStepId);
  }

  @override
  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity, String userId) async {
    await remoteDataSource.createDefaultPreparation(preparationEntity, userId);
  }

  @override
  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId) async {
    await remoteDataSource.createCustomPreparation(
        preparationEntity, scheduleId);
  }

  @override
  Future<void> updatePreparation(
      PreparationStepEntity preparationEntity) async {
    await localDataSource.updatePreparation(preparationEntity);
  }

  @override
  Future<void> deletePreparation(PreparationEntity preparationEntity) async {
    await localDataSource.deletePreparation(preparationEntity);
  }
}
