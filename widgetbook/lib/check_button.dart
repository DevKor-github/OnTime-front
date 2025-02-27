import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/shared/components/check_button.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: CheckButton,
)
Widget useCaseCheckButton(BuildContext context) {
  final isChecked = context.knobs.boolean(
    label: 'Checked',
    initialValue: true,
  );
  return CheckButton(
    isChecked: isChecked,
    onPressed: () {},
  );
}
