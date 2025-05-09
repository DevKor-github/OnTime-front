import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/shared/theme/theme.dart';

@widgetbook.UseCase(
  name: 'Default',
  type: ModalButton,
)
Widget useCaseModalButton(BuildContext context) {
  final buttonText = context.knobs.string(
    label: 'Button Text',
    initialValue: 'Text',
  );

  final backgroundColor = context.knobs.list<Color>(
    label: 'Button Color',
    options: [
      colorScheme.primary,
      colorScheme.surfaceContainer,
      colorScheme.error,
    ],
    initialOption: colorScheme.primary,
  );

  final textColor = context.knobs.list<Color>(
    label: 'Text Color',
    options: [
      colorScheme.onPrimary,
      colorScheme.outline,
      colorScheme.onError,
    ],
    initialOption: colorScheme.onPrimary,
  );

  return Center(
    child: ModalButton(
      text: buttonText,
      color: backgroundColor,
      textColor: textColor,
      onPressed: () {},
    ),
  );
}
