import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/components/preparation_time_tild.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/cubit/preparation_time_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: PreparationTimeTile,
)
Widget useCasePreparationTimeTile(BuildContext context) {
  final preparationName = context.knobs.string(
    label: 'Preparation Name',
    initialValue: '샤워하기',
  );

  final preparationMinute = context.knobs.int.input(
    label: 'Preparation Time',
    initialValue: 30,
  );

  return IgnorePointer(
    child: PreparationTimeTile(
      value: PreparationStepTimeState(
          preparationId: 'preparationId',
          preparationName: preparationName,
          preparationTime: PreparationTimeInputModel.dirty(
              Duration(minutes: preparationMinute))),
      index: 0,
      onPreparationTimeChanged: (_, __) {},
    ),
  );
}
