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
  final listLength = context.knobs.int.slider(
    label: 'Number of Steps',
    initialValue: 3,
    min: 1,
    max: 6,
  );

  final stepElapsedTime = context.knobs.int.slider(
    label: 'Step Elapsed Time (sec)',
    initialValue: 15,
    min: 0,
    max: 120,
  );

  final preparationSteps = [
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
    PreparationStepEntity(
      id: const Uuid().v7(),
      preparationName: '옷 갈아입기',
      preparationTime: const Duration(seconds: 60),
      nextPreparationId: const Uuid().v7(),
    ),
    PreparationStepEntity(
      id: const Uuid().v7(),
      preparationName: '화장하기',
      preparationTime: const Duration(seconds: 60),
      nextPreparationId: const Uuid().v7(),
    ),
    PreparationStepEntity(
      id: const Uuid().v7(),
      preparationName: '고양이 밥주기',
      preparationTime: const Duration(seconds: 60),
      nextPreparationId: const Uuid().v7(),
    ),
    PreparationStepEntity(
      id: const Uuid().v7(),
      preparationName: '화분에 물주기',
      preparationTime: const Duration(seconds: 60),
      nextPreparationId: const Uuid().v7(),
    ),
  ].sublist(0, listLength);

  final currentStepIndex = context.knobs.int.slider(
    label: 'Current Step Index',
    initialValue: 0,
    min: 0,
    max: 6,
  );

  final stepStates = List<PreparationStateEnum>.generate(
    listLength,
    (index) => index < currentStepIndex
        ? PreparationStateEnum.done
        : (index == currentStepIndex
            ? PreparationStateEnum.now
            : PreparationStateEnum.yet),
  );

  final width = context.knobs.double.slider(
    label: 'Width',
    initialValue: 400,
    min: 200,
    max: 600,
  );

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 243, 241, 241),
    body: Center(
      child: SizedBox(
        width: width,
        height: 400,
        child: PreparationStepListWidget(
          preparationSteps: preparationSteps,
          currentStepIndex: currentStepIndex,
          stepElapsedTimes: List.generate(listLength, (_) => stepElapsedTime),
          preparationStepStates: stepStates,
          onSkip: () {},
        ),
      ),
    ),
  );
}
