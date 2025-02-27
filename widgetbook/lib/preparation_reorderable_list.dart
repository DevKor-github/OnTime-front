import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';
import 'package:uuid/uuid.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/components/preparation_reorderable_list.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: PreparationReorderableList,
)
Widget useCasePreparationReorderableList(BuildContext context) {
  final preparationLength = context.knobs.int
      .slider(label: 'Preparation Length', initialValue: 4, min: 1, max: 7);
  final preparationOrderingList = [
    PreparationStepOrderState(
        preparationId: const Uuid().v7(), preparationName: '샤워하기'),
    PreparationStepOrderState(
        preparationId: const Uuid().v7(), preparationName: '양치하기'),
    PreparationStepOrderState(
        preparationId: const Uuid().v7(), preparationName: '화장하기'),
    PreparationStepOrderState(
        preparationId: const Uuid().v7(), preparationName: '옷 입기'),
    PreparationStepOrderState(
        preparationId: const Uuid().v7(), preparationName: '짐 챙기기'),
    PreparationStepOrderState(
        preparationId: const Uuid().v7(), preparationName: '약 챙기기'),
    PreparationStepOrderState(
        preparationId: const Uuid().v7(), preparationName: '머리 세팅하기'),
  ];

  return IgnorePointer(
    child: PreparationReorderableList(
      preparationOrderingList:
          preparationOrderingList.sublist(0, preparationLength).toList(),
      onReorder: (int oldIndex, int newIndex) {},
    ),
  );
}
