import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: ModalWideButton,
)
Widget modalWideButtonDefaultUseCase(BuildContext context) {
  final text = context.knobs.string(
    label: 'Text',
    initialValue: '취소',
  );
  final height = context.knobs.double.slider(
    label: 'Height',
    initialValue: 43,
    min: 36,
    max: 56,
  );
  final enabled = context.knobs.boolean(
    label: 'Enabled',
    initialValue: true,
  );

  final button = ModalWideButton(
    text: text,
    height: height,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    textColor: Theme.of(context).colorScheme.outline,
    onPressed: () {},
  );

  return Center(
    child: IgnorePointer(
      ignoring: !enabled,
      child: Opacity(opacity: enabled ? 1 : 0.5, child: button),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Destructive',
  type: ModalWideButton,
)
Widget modalWideButtonDestructiveUseCase(BuildContext context) {
  final text = context.knobs.string(
    label: 'Text',
    initialValue: '약속 삭제',
  );
  final height = context.knobs.double.slider(
    label: 'Height',
    initialValue: 43,
    min: 36,
    max: 56,
  );
  final enabled = context.knobs.boolean(
    label: 'Enabled',
    initialValue: true,
  );

  final button = ModalWideButton(
    text: text,
    height: height,
    color: Theme.of(context).colorScheme.error,
    textColor: Theme.of(context).colorScheme.onError,
    onPressed: () {},
  );

  return Center(
    child: IgnorePointer(
      ignoring: !enabled,
      child: Opacity(opacity: enabled ? 1 : 0.5, child: button),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Flexible Row',
  type: ModalWideButton,
)
Widget modalWideButtonFlexibleRowUseCase(BuildContext context) {
  final leftText = context.knobs.string(
    label: 'Left Text',
    initialValue: '취소',
  );
  final rightText = context.knobs.string(
    label: 'Right Text',
    initialValue: '약속 삭제',
  );
  final height = context.knobs.double.slider(
    label: 'Height',
    initialValue: 43,
    min: 36,
    max: 56,
  );
  final enabled = context.knobs.boolean(
    label: 'Enabled',
    initialValue: true,
  );

  return Center(
    child: SizedBox(
      width: 277,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Row(
            children: [
              ModalWideButton(
                isFlexible: true,
                text: leftText,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                textColor: Theme.of(context).colorScheme.outline,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              ModalWideButton(
                isFlexible: true,
                text: rightText,
                height: height,
                color: Theme.of(context).colorScheme.error,
                textColor: Theme.of(context).colorScheme.onError,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
