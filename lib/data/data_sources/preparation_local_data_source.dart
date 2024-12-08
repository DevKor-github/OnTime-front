import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

abstract interface class PreparationLocalDataSource {
  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity, String userId);

  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> updatePreparation(PreparationStepEntity preparationStepEntity);

  Future<void> deletePreparation(PreparationEntity preparationEntity);

  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId);
}

class PreparationLocalDataSourceImpl implements PreparationLocalDataSource {
  final AppDatabase appDatabase;

  PreparationLocalDataSourceImpl({required this.appDatabase});

  @override
  Future<void> createDefaultPreparation(
      PreparationEntity preparationEntity, String userId) async {
    await appDatabase.preparationUserDao
        .createPreparationUser(preparationEntity, userId);
  }

  @override
  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId) async {
    await appDatabase.preparationScheduleDao
        .createPreparationSchedule(preparationEntity, scheduleId);
  }

  @override
  Future<PreparationEntity> getPreparationByScheduleId(
      String scheduleId) async {
    final schedules = await appDatabase.preparationScheduleDao
        .getPreparationSchedulesByScheduleId(scheduleId);
    return schedules.isNotEmpty
        ? schedules.first
        : PreparationEntity(preparationStepList: []);
  }

  @override
  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) async {
    return await appDatabase.preparationScheduleDao
        .getPreparationStepById(preparationStepId);
  }

  @override
  Future<void> deletePreparation(PreparationEntity preparationEntity) async {
    for (var step in preparationEntity.preparationStepList) {
      if (step.nextPreparationId != null) {
        // 스케줄 기반 삭제
        await appDatabase.preparationScheduleDao
            .deletePreparationSchedule(step.id);
      } else {
        // 사용자 기반 삭제
        await appDatabase.preparationUserDao.deletePreparationUser(step.id);
      }
    }
  }

  @override
  Future<void> updatePreparation(
      PreparationStepEntity preparationStepEntity) async {
    if (preparationStepEntity.nextPreparationId != null) {
      // 스케줄 기반 업데이트
      await appDatabase.preparationScheduleDao
          .updatePreparationSchedule(preparationStepEntity, 'scheduleId');
    } else {
      // 사용자 기반 업데이트
      await appDatabase.preparationUserDao
          .updatePreparationUser(preparationStepEntity, 'userId');
    }
  }
}
