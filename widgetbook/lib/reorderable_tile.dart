import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/components/reorderable_tile.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: ReorderableTile,
)
Widget useCaseReorderableTile(BuildContext context) {
  final preparationStepName = context.knobs.string(
    label: 'Preparation Name',
    initialValue: '샤워하기',
  );

  return ReorderableTile(
    preparationStepOrderState: PreparationStepOrderState(
      preparationId: 'Preparation ID',
      preparationName: preparationStepName,
    ),
    index: 0,
  );
}
