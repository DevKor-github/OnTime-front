import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/components/create_icon_button.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: CreateIconButton,
)
Widget useCaseCreateIconButton(BuildContext context) {
  return CreateIconButton(
    onCreationRequested: () {},
  );
}
