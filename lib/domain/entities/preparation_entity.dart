import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class PreparationEntity extends Equatable {
  final List<PreparationStepEntity> preparationStepList;

  const PreparationEntity({
    required this.preparationStepList,
  });

  Duration get totalDuration {
    return preparationStepList.fold(
      Duration.zero,
      (previousValue, element) => previousValue + element.preparationTime,
    );
  }

  @override
  String toString() {
    return 'PreparationEntity(preparationStepList: ${preparationStepList.toString()})';
  }

  @override
  List<Object?> get props => [preparationStepList];
}
