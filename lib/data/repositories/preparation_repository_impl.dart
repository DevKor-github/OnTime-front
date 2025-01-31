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
      PreparationEntity preparationEntity) async {
    try {
      await preparationRemoteDataSource
          .createDefaultPreparation(preparationEntity);
      await preparationLocalDataSource
          .createDefaultPreparation(preparationEntity);
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
  Future<PreparationEntity> getPreparationByScheduleId(
      String scheduleId) async {
    try {
      final remotePreparation = await preparationRemoteDataSource
          .getPreparationByScheduleId(scheduleId);
      return remotePreparation;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) async {
    try {
      final remoteStep = await preparationRemoteDataSource
          .getPreparationStepById(preparationStepId);
      return remoteStep;
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
