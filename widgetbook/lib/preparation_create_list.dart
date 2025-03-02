import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/preparation_create_list.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:uuid/uuid.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: PreparationCreateList,
)
Widget useCasePreparationCreateList(BuildContext context) {
  final preparationLength = context.knobs.int
      .slider(label: 'Preparation Length', initialValue: 4, min: 1, max: 7);
  final preparationOrderingList = [
    PreparationStepNameState(
        preparationId: const Uuid().v7(),
        preparationName: const PreparationNameInputModel.dirty('샤워하기')),
    PreparationStepNameState(
        preparationId: const Uuid().v7(),
        preparationName: const PreparationNameInputModel.dirty('양치하기')),
    PreparationStepNameState(
        preparationId: const Uuid().v7(),
        preparationName: const PreparationNameInputModel.dirty('화장하기')),
    PreparationStepNameState(
        preparationId: const Uuid().v7(),
        preparationName: const PreparationNameInputModel.dirty('옷 입기')),
    PreparationStepNameState(
        preparationId: const Uuid().v7(),
        preparationName: const PreparationNameInputModel.dirty('짐 챙기기')),
    PreparationStepNameState(
        preparationId: const Uuid().v7(),
        preparationName: const PreparationNameInputModel.dirty('약 챙기기')),
    PreparationStepNameState(
        preparationId: const Uuid().v7(),
        preparationName: const PreparationNameInputModel.dirty('머리 세팅하기')),
  ];
  return PreparationCreateList(
    preparationNameState: PreparationNameState(
      preparationStepList:
          preparationOrderingList.sublist(0, preparationLength).toList(),
    ),
    onCreationRequested: () {},
    onNameChanged: ({required int index, required String value}) {},
    onSelectionChanged: ({required int index}) {},
  );
}
