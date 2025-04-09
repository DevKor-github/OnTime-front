import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_component.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/shared/theme/theme.dart';

@widgetbook.UseCase(
  name: 'Dynamic Buttons',
  type: ModalComponent,
)
Widget useCaseModalComponent(BuildContext context) {
  final titleText = context.knobs.string(
    label: 'Modal Title',
    initialValue: 'Modal Title',
  );

  final contentText = context.knobs.string(
    label: 'Modal Detail',
    initialValue: 'Modal Detail',
  );

  final showFirstButton = context.knobs.boolean(
    label: 'First Button',
    initialValue: true,
  );

  final firstButtonText = context.knobs.string(
    label: 'Button Text',
    initialValue: 'Button',
  );

  final List<Widget> buttons = [];

  if (showFirstButton) {
    buttons.add(
      ModalButton(
        onPressed: () {},
        text: firstButtonText,
        color: colorScheme.surfaceContainer,
        textColor: colorScheme.outline,
      ),
    );
  }

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 243, 241, 241),
    body: Center(
      child: ModalComponent(
        title: Text(titleText),
        content: Text(contentText),
        actions: buttons,
      ),
    ),
  );
}
