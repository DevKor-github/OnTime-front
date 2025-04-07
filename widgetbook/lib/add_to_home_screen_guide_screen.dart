import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/notification_permission/screens/add_to_home_screen_guide_screen.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: AddToHomeScreenGuideScreen,
)
Widget addTohomeGuideScreenUseCase(BuildContext context) {
  return const AddToHomeScreenGuideScreen();
}
