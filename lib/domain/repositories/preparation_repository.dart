import 'package:on_time_front/domain/entities/preparation_entity.dart';

abstract interface class PreparationRepository {
  Future<PreparationEntity> getPreparationByScheduleId(String scheduleId);

  Future<PreparationEntity> getDefualtPreparation();

  Future<void> createDefaultPreparation(
      {required PreparationEntity preparationEntity,
      required Duration spareTime,
      required String note});

  Future<void> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> updateDefaultPreparation(PreparationEntity preparationEntity);

  Future<void> updatePreparationByScheduleId(
      PreparationEntity preparationEntity, String scheduleId);

  Future<void> updateSpareTime(Duration newSpareTime);
}
