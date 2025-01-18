import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/onboarding/preparation_reordarable_list.dart';

@widgetbook.UseCase(name: 'Default', type: PreparationReorderableList)
Widget buildTileUseCase(BuildContext context) {
  return Scaffold(
      body: PreparationReorderableList(
    preparationOrderingList: [
      PreparationStepWithOriginalIndex(
        originalIndex: 0,
        preparationStep: PreparationStepWithNameAndId(
          id: '1',
          preparationName: 'Preparation 1',
        ),
      ),
    ],
    onReorder: (int oldIndex, int newIndex) {},
  ));
}
