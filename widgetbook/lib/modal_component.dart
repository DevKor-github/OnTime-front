import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_component.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/shared/theme/theme.dart';

@widgetbook.UseCase(
  name: 'default',
  type: ModalComponent,
)
Widget useCaseModalComponent(BuildContext context) {
  final double containerWidth = context.knobs.double.slider(
    label: 'Container Width',
    initialValue: 276,
    min: 200,
    max: 400,
  );

  final String modalTitleText = context.knobs.string(
    label: 'Modal Title Text',
    initialValue: 'Title Text',
  );

  final String modalDetailText = context.knobs.string(
    label: 'Modal Detail Text',
    initialValue: 'Detail Text',
  );

  final String leftButtonText = context.knobs.string(
    label: 'Left Button Text',
    initialValue: 'Left',
  );

  final String rightButtonText = context.knobs.string(
    label: 'Right Button Text',
    initialValue: 'Right',
  );

  final Color leftButtonColor = context.knobs.list<Color>(
    label: 'Left Button Color',
    initialOption: colorScheme.surfaceDim,
    options: [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.error,
      colorScheme.surfaceDim,
    ],
  );

  final Color leftButtonTextColor = context.knobs.list<Color>(
    label: 'Left Button Text Color',
    initialOption: colorScheme.onSurface,
    options: [
      colorScheme.onPrimary,
      colorScheme.onSecondary,
      colorScheme.onError,
      colorScheme.onSurface,
    ],
  );

  final Color rightButtonColor = context.knobs.list<Color>(
    label: 'Right Button Color',
    options: [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.error,
      colorScheme.surface,
    ],
  );

  final Color rightButtonTextColor = context.knobs.list<Color>(
    label: 'Right Button Text Color',
    initialOption: colorScheme.onPrimary,
    options: [
      colorScheme.onPrimary,
      colorScheme.onSecondary,
      colorScheme.onError,
      colorScheme.onSurface,
    ],
  );

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 243, 241, 241),
    body: Center(
      child: SizedBox(
        child: ModalComponent(
          leftPressed: () {},
          rightPressed: () {},
          modalTitleText: modalTitleText,
          modalDetailText: modalDetailText,
          leftButtonText: leftButtonText,
          rightButtonText: rightButtonText,
          leftButtonColor: leftButtonColor,
          leftButtonTextColor: leftButtonTextColor,
          rightButtonColor: rightButtonColor,
          rightButtonTextColor: rightButtonTextColor,
          containerWidth: containerWidth,
        ),
      ),
    ),
  );
}
