import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';

class StartedScheduleEntity extends Equatable {
  const StartedScheduleEntity({
    required this.schedule,
    required this.preparation,
  });

  final ScheduleEntity schedule;
  final PreparationWithTimeEntity preparation;

  ScheduleWithPreparationEntity get scheduleWithPreparation =>
      ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
        schedule,
        preparation,
      );

  @override
  List<Object?> get props => [schedule, preparation];
}
