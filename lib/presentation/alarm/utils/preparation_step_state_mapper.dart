import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

extension PreparationStepStateMapper on PreparationWithTimeEntity {
  List<PreparationStateEnum> get preparationStepStates {
    final resolvedIndex = resolvedCurrentStepIndex;

    return List<PreparationStateEnum>.generate(preparationStepList.length, (
      index,
    ) {
      if (isAllStepsDone) {
        return PreparationStateEnum.done;
      }
      if (index < resolvedIndex) {
        return PreparationStateEnum.done;
      }
      if (index == resolvedIndex && !isAllStepsDone) {
        return PreparationStateEnum.now;
      }
      return PreparationStateEnum.yet;
    });
  }
}
