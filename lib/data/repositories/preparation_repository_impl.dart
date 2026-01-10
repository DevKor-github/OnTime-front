import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';
import 'package:on_time_front/data/models/create_defualt_preparation_request_model.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';

import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: PreparationRepository)
class PreparationRepositoryImpl implements PreparationRepository {
  final PreparationRemoteDataSource preparationRemoteDataSource;
  final PreparationLocalDataSource preparationLocalDataSource;

  late final _preparationStreamController =
      BehaviorSubject<Map<String, PreparationEntity>>.seeded(
    const <String, PreparationEntity>{},
  );

  PreparationRepositoryImpl({
    required this.preparationRemoteDataSource,
    required this.preparationLocalDataSource,
  });

  @override
  Stream<Map<String, PreparationEntity>> get preparationStream =>
      _preparationStreamController.asBroadcastStream();

  @override
  Future<void> createDefaultPreparation(
      {required PreparationEntity preparationEntity,
      required Duration spareTime,
      required String note}) async {
    try {
      await preparationRemoteDataSource.createDefaultPreparation(
          CreateDefaultPreparationRequestModel.fromEntity(
              preparationEntity: preparationEntity,
              spareTime: spareTime,
              note: note));
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
      _preparationStreamController.add(
          Map.from(_preparationStreamController.value)
            ..[scheduleId] = preparationEntity);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> getPreparationByScheduleId(String scheduleId) async {
    try {
      final remotePreparation = await preparationRemoteDataSource
          .getPreparationByScheduleId(scheduleId);
      _preparationStreamController.add(
          Map.from(_preparationStreamController.value)
            ..[scheduleId] = remotePreparation);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<PreparationEntity> getDefualtPreparation() async {
    try {
      final remotePreparation =
          await preparationRemoteDataSource.getDefualtPreparation();
      return remotePreparation;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateDefaultPreparation(
      PreparationEntity preparationEntity) async {
    try {
      await preparationRemoteDataSource
          .updateDefaultPreparation(preparationEntity);
      // await preparationLocalDataSource.updatePreparation(preparationEntity);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePreparationByScheduleId(
      PreparationEntity preparationEntity, String scheduleId) async {
    try {
      await preparationRemoteDataSource.updatePreparationByScheduleId(
          preparationEntity, scheduleId);
      _preparationStreamController.add(
          Map.from(_preparationStreamController.value)
            ..[scheduleId] = preparationEntity);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSpareTime(Duration newSpareTime) async {
    try {
      await preparationRemoteDataSource.updateSpareTime(newSpareTime);
    } catch (e) {
      rethrow;
    }
  }
}
