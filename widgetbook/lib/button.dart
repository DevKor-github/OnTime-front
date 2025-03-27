import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/shared/components/button.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: Button,
)
Widget buttonUseCase(BuildContext context) {
  final label = context.knobs.string(label: 'Text', initialValue: 'Click Me');
  final size = context.knobs.list<ButtonSize>(
      label: 'Size',
      options: ButtonSize.values,
      initialOption: ButtonSize.Giant);

  return Center(
    child: Button(
      text: label,
      size: size,
      onPressed: () {},
    ),
  );
}
