import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

class ScheduleFormSubmission extends Equatable {
  final ScheduleEntity schedule;
  final PreparationEntity preparation;
  final bool preparationChanged;

  const ScheduleFormSubmission({
    required this.schedule,
    required this.preparation,
    required this.preparationChanged,
  });

  @override
  List<Object?> get props => [schedule, preparation, preparationChanged];
}
