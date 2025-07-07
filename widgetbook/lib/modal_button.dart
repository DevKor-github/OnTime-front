import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: ModalButton,
)
Widget useCaseModalButton(BuildContext context) {
  final buttonText = context.knobs.string(
    label: 'Button Text',
    initialValue: 'Text',
  );
  return Center(
    child: ModalButton(
      text: buttonText,
      onPressed: () {},
    ),
  );
}
