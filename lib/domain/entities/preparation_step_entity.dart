import 'package:on_time_front/core/database/database.dart';

class PreparationStepEntity {
  final int id;
  final String preparationName;
  final int preparationTime;
  final int order;

  PreparationStepEntity({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.order,
  });

  PreparationUser toUserModel(int userId) {
    return PreparationUser(
      id: id,
      userId: userId,
      preparationName: preparationName,
      preparationTime: preparationTime,
      order: order,
    );
  }

  PreparationSchedule toScheduleModel(int scheduleId) {
    return PreparationSchedule(
      id: id,
      scheduleId: scheduleId,
      preparationName: preparationName,
      preparationTime: preparationTime,
      order: order,
    );
  }

  @override
  String toString() {
    return 'PreparationStepEntity(id: $id, preparationName: $preparationName, preparationTime: $preparationTime, order: $order)';
  }
}
