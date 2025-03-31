import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_tile.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: PreparationStepTile,
)
Widget preparationStepTileUseCase(BuildContext context) {
  final index = context.knobs.int.slider(
    label: 'Step Index',
    initialValue: 1,
    min: 1,
    max: 5,
  );

  final elapsed = context.knobs.int.slider(
    label: 'Elapsed Seconds',
    initialValue: 20,
    min: 0,
    max: 120,
  );

  final state = context.knobs.list<PreparationStateEnum>(
    label: 'Step State',
    options: PreparationStateEnum.values,
    initialOption: PreparationStateEnum.now,
  );

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 243, 241, 241),
    body: Center(
      child: SizedBox(
        width: 400,
        height: 200,
        child: PreparationStepTile(
          stepIndex: index,
          preparationName: '가방 챙기기',
          preparationTime: '01:20',
          isLastItem: false,
          onSkip: () {},
          stepElapsedTime: elapsed,
          preparationStepState: state,
        ),
      ),
    ),
  );
}
