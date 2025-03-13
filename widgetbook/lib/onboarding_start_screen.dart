import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_start_screen.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: OnboardingStartScreen,
)
Widget useCaseOnboardingStartScreen(BuildContext context) {
  return const OnboardingStartScreen();
}
