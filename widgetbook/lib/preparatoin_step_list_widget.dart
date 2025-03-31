import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_list_widget.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';
import 'package:uuid/uuid.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: PreparationStepListWidget,
)
Widget preparationStepListWidgetUseCase(BuildContext context) {
  final currentStepIndex = context.knobs.int.slider(
    label: 'Current Step Index',
    initialValue: 0,
    min: 0,
    max: 1,
  );

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 243, 241, 241),
    body: Center(
      child: SizedBox(
        height: 400,
        child: PreparationStepListWidget(
          preparationSteps: [
            PreparationStepEntity(
              id: const Uuid().v7(),
              preparationName: '양치하기',
              preparationTime: const Duration(seconds: 60),
              nextPreparationId: const Uuid().v7(),
            ),
            PreparationStepEntity(
              id: const Uuid().v7(),
              preparationName: '가방 챙기기',
              preparationTime: const Duration(seconds: 60),
              nextPreparationId: const Uuid().v7(),
            ),
          ],
          currentStepIndex: currentStepIndex,
          stepElapsedTimes: const [15, 0],
          preparationStepStates: const [
            PreparationStateEnum.now,
            PreparationStateEnum.yet,
          ],
          onSkip: () {},
        ),
      ),
    ),
  );
}
