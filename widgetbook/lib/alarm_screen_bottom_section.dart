import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_bottom_section.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';
import 'package:uuid/uuid.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: AlarmScreenBottomSection,
)
Widget alarmScreenBottomSectionUseCase(BuildContext context) {
  final currentStepIndex = context.knobs.int.slider(
    label: 'Current Step Index',
    initialValue: 0,
    min: 0,
    max: 1,
  );

  return AlarmScreenBottomSection(
    preparationSteps: [
      PreparationStepEntity(
        id: const Uuid().v7(),
        preparationName: '세수하기',
        preparationTime: const Duration(seconds: 60),
        nextPreparationId: const Uuid().v7(),
      ),
      PreparationStepEntity(
        id: const Uuid().v7(),
        preparationName: '양치하기',
        preparationTime: const Duration(seconds: 60),
      ),
    ],
    currentStepIndex: currentStepIndex,
    stepElapsedTimes: const [10, 0],
    preparationStepStates: const [
      PreparationStateEnum.now,
      PreparationStateEnum.yet,
    ],
    onSkip: () {},
    onEndPreparation: () {},
  );
}
