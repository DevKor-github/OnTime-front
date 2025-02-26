import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/step_progress.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(name: 'Onboarding Form', type: StepProgress)
Widget onboardingFormStepProgress(BuildContext context) {
  final totalSteps =
      context.knobs.int.input(label: 'Number of Total Steps', initialValue: 5);

  final currentStep = context.knobs.int.slider(
    label: 'Current Step',
    initialValue: 0,
    min: 0,
    max: totalSteps - 1,
  );

  return StepProgress(
    currentStep: currentStep,
    totalSteps: totalSteps,
  );
}

@widgetbook.UseCase(name: 'Schedule Form', type: StepProgress)
Widget scheduleFormStepProgress(BuildContext context) {
  final totalSteps =
      context.knobs.int.input(label: 'Number of Total Steps', initialValue: 5);

  final currentStep = context.knobs.int.slider(
    label: 'Current Step',
    initialValue: 0,
    min: 0,
    max: totalSteps - 1,
  );

  return StepProgress(
    currentStep: currentStep,
    totalSteps: totalSteps,
    singleLine: true,
  );
}
