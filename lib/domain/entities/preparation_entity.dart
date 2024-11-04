import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class PreparationEntity {
  List<PreparationStepEntity> preparationStepList;

  PreparationEntity({
    required this.preparationStepList,
  });

  @override
  String toString() {
    return 'PreparationEntity(preparationStepList: ${preparationStepList.toString()})';
  }
}
