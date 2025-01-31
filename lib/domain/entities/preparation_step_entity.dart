import 'package:on_time_front/core/database/database.dart';

class PreparationStepEntity {
  final String id;
  final String preparationName;
  final Duration preparationTime;
  String? nextPreparationId;

  PreparationStepEntity({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    this.nextPreparationId,
  });

  PreparationUser toPreparationUserModel(String userId) {
    return PreparationUser(
      id: id,
      userId: userId,
      preparationName: preparationName,
      preparationTime: preparationTime.inMinutes,
      nextPreparationId: nextPreparationId,
    );
  }

  PreparationSchedule toPreparationScheduleModel(String scheduleId) {
    return PreparationSchedule(
      id: id,
      scheduleId: scheduleId,
      preparationName: preparationName,
      preparationTime: preparationTime.inMinutes,
      nextPreparationId: nextPreparationId,
    );
  }

  void updateNextPreparationId(String? newNextId) {
    nextPreparationId = newNextId;
  }

  @override
  String toString() {
    return 'PreparationStepEntity(id: $id, preparationName: $preparationName, preparationTime: $preparationTime, nextPreparationId: $nextPreparationId)';
  }

  PreparationStepEntity copyWith({
    String? id,
    String? preparationName,
    Duration? preparationTime,
    String? nextPreparationId,
  }) {
    return PreparationStepEntity(
      id: id ?? this.id,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      nextPreparationId: nextPreparationId ?? this.nextPreparationId,
    );
  }
}
