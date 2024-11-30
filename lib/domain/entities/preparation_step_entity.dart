import 'package:on_time_front/core/database/database.dart';

class PreparationStepEntity {
  final String id;
  final String preparationName;
  final int preparationTime;
  final String? nextPreparationId;

  PreparationStepEntity({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.nextPreparationId,
  });

  PreparationUser toPreparationUserModel(String userId) {
    return PreparationUser(
      id: id,
      userId: userId,
      preparationName: preparationName,
      preparationTime: preparationTime,
      nextPreparationId: nextPreparationId,
    );
  }

  PreparationSchedule toPreparationScheduleModel(String scheduleId) {
    return PreparationSchedule(
      id: id,
      scheduleId: scheduleId,
      preparationName: preparationName,
      preparationTime: preparationTime,
      nextPreparationId: nextPreparationId,
    );
  }

  @override
  String toString() {
    return 'PreparationStepEntity(id: $id, preparationName: $preparationName, preparationTime: $preparationTime, nextPreparationId: $nextPreparationId)';
  }
}
