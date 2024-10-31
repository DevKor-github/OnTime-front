import 'package:on_time_front/config/database.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

class PreparationScheduleEntity {
  final int id;
  final ScheduleEntity schedule;
  final String preparationName;
  final int preparationTime;
  final int order;

  PreparationScheduleEntity({
    required this.id,
    required this.schedule,
    required this.preparationName,
    required this.preparationTime,
    required this.order,
  });

  static PreparationScheduleEntity fromModel(
      PreparationSchedule preparationSchedule,
      Schedule schedule,
      User user,
      Place place) {
    return PreparationScheduleEntity(
      id: preparationSchedule.id,
      schedule: ScheduleEntity.fromModel(schedule, user, place),
      preparationName: preparationSchedule.preparationName,
      preparationTime: preparationSchedule.preparationTime,
      order: preparationSchedule.order,
    );
  }

  PreparationSchedule toModel() {
    return PreparationSchedule(
      id: id,
      scheduleId: schedule.id,
      preparationName: preparationName,
      preparationTime: preparationTime,
      order: order,
    );
  }

  @override
  String toString() {
    return 'PreparationScheduleEntity(id: $id, schedule: $schedule, preparationName: $preparationName, preparationTime: $preparationTime, order: $order)';
  }
}
