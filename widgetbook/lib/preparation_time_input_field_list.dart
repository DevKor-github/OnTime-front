import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:uuid/uuid.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/components/preparation_time_input_list.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: PreparationTimeInputFieldList,
)
Widget useCasePreparationTimeInputFieldList(BuildContext context) {
  final preparationLength = context.knobs.int
      .slider(label: 'Preparation Length', initialValue: 4, min: 1, max: 7);
  final preparationOrderingList = [
    PreparationStepTimeState(
      preparationId: const Uuid().v7(),
      preparationName: '샤워하기',
      preparationTime:
          const PreparationTimeInputModel.dirty(Duration(minutes: 10)),
    ),
    PreparationStepTimeState(
        preparationId: const Uuid().v7(),
        preparationName: '양치하기',
        preparationTime:
            const PreparationTimeInputModel.dirty(Duration(minutes: 5))),
    PreparationStepTimeState(
        preparationId: const Uuid().v7(),
        preparationName: '화장하기',
        preparationTime:
            const PreparationTimeInputModel.dirty(Duration(minutes: 15))),
    PreparationStepTimeState(
        preparationId: const Uuid().v7(),
        preparationName: '옷 입기',
        preparationTime:
            const PreparationTimeInputModel.dirty(Duration(minutes: 10))),
    PreparationStepTimeState(
        preparationId: const Uuid().v7(),
        preparationName: '짐 챙기기',
        preparationTime:
            const PreparationTimeInputModel.dirty(Duration(minutes: 5))),
    PreparationStepTimeState(
        preparationId: const Uuid().v7(),
        preparationName: '약 챙기기',
        preparationTime:
            const PreparationTimeInputModel.dirty(Duration(minutes: 5))),
    PreparationStepTimeState(
        preparationId: const Uuid().v7(),
        preparationName: '머리 세팅하기',
        preparationTime:
            const PreparationTimeInputModel.dirty(Duration(minutes: 5))),
  ];

  return IgnorePointer(
    child: PreparationTimeInputFieldList(
      preparationTimeList:
          preparationOrderingList.sublist(0, preparationLength),
      onPreparationTimeChanged: (_, __) {},
    ),
  );
}
