import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class PreparationEntity extends Equatable {
  final List<PreparationStepEntity> preparationStepList;

  const PreparationEntity({
    required this.preparationStepList,
  });

  @override
  String toString() {
    return 'PreparationEntity(preparationStepList: ${preparationStepList.toString()})';
  }

  @override
  List<Object?> get props => [preparationStepList];
}
