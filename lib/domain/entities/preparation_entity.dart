import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class PreparationEntity {
  List<PreparationStepEntity> preparationStepList;

  PreparationEntity({
    required this.preparationStepList,
  });

  PreparationEntity toModel() {
    return PreparationEntity(preparationStepList: preparationStepList);
  }

  @override
  String toString() {
    return 'PreparationEntity(preparationStepList: ${preparationStepList.toString()})';
  }

  toPreparationUserEntity(String userId) {}

  List<PreparationSchedule> toPreparationScheduleModelList(String scheduleId) {
    return preparationStepList
        .map(
          (e) => PreparationSchedule(
            preparationName: e.preparationName,
            preparationTime: e.preparationTime,
            order: e.order,
            scheduleId: scheduleId,
            id: 'scheduleId',
          ),
        )
        .toList();
  }

  List<PreparationUser> toPreparationUserModelList(String userId) {
    return preparationStepList
        .map(
          (e) => PreparationUser(
            preparationName: e.preparationName,
            preparationTime: e.preparationTime,
            order: e.order,
            userId: userId,
            id: 'userId',
          ),
        )
        .toList();
  }
}
