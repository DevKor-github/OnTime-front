import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_list_widget.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('renders ordered preparation steps and wires skip action', (
    tester,
  ) async {
    var skipCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Scaffold(
          body: PreparationStepListWidget(
            preparationSteps: _steps,
            currentStepIndex: 1,
            stepElapsedTimes: const [0, 90, 120],
            preparationStepStates: const [
              PreparationStateEnum.done,
              PreparationStateEnum.now,
              PreparationStateEnum.yet,
            ],
            onSkip: () => skipCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('Wake up'), findsOneWidget);
    expect(find.text('Shower'), findsOneWidget);
    expect(find.text('Leave home'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('1분 30초'), findsOneWidget);
    expect(find.text('이 단계 건너 뛰기'), findsOneWidget);

    await tester.tap(find.text('이 단계 건너 뛰기'));
    await tester.pump();

    expect(skipCount, 1);
  });

  testWidgets('scrolls toward the previous step when current step advances', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Scaffold(
          body: PreparationStepListWidget(
            preparationSteps: _steps,
            currentStepIndex: 1,
            stepElapsedTimes: const [0, 90, 120],
            preparationStepStates: const [
              PreparationStateEnum.done,
              PreparationStateEnum.done,
              PreparationStateEnum.now,
            ],
            onSkip: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Scaffold(
          body: PreparationStepListWidget(
            preparationSteps: _steps,
            currentStepIndex: 2,
            stepElapsedTimes: const [0, 90, 120],
            preparationStepStates: const [
              PreparationStateEnum.done,
              PreparationStateEnum.done,
              PreparationStateEnum.now,
            ],
            onSkip: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Leave home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _steps = [
  PreparationStepEntity(
    id: 'step-1',
    preparationName: 'Wake up',
    preparationTime: Duration(minutes: 5),
    nextPreparationId: 'step-2',
  ),
  PreparationStepEntity(
    id: 'step-2',
    preparationName: 'Shower',
    preparationTime: Duration(minutes: 10),
    nextPreparationId: 'step-3',
  ),
  PreparationStepEntity(
    id: 'step-3',
    preparationName: 'Leave home',
    preparationTime: Duration(minutes: 15),
  ),
];
