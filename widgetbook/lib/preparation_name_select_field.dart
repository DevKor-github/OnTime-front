import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/preparation_name_select_field.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: PreparationNameSelectField,
)
Widget useCasePreparationNameSelectField(BuildContext context) {
  final isChecked = context.knobs.boolean(
    label: 'Checked',
    initialValue: true,
  );
  return PreparationNameSelectField(
    preparationStep: PreparationStepNameState(
      preparationName: const PreparationNameInputModel.dirty('샤워하기'),
      isSelected: isChecked,
    ),
    onNameChanged: (_) {},
    onNameSaved: () {},
    onSelectionChanged: () {},
    isAdding: false,
  );
}
