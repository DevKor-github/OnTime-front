import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

// ElevatedButton Use Cases (has custom AppButtonStyles.elevatedPrimary theme)
@widgetbook.UseCase(
  name: 'default',
  type: ElevatedButton,
)
Widget useCaseElevatedButton(BuildContext context) {
  final text = context.knobs.string(
    label: 'Text',
    initialValue: 'Button',
  );
  final enabled = context.knobs.boolean(
    label: 'Enabled',
    initialValue: true,
  );

  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: enabled ? () {} : null,
      child: Text(text),
    ),
  );
}

// TextButton Use Cases (has custom AppButtonStyles.textPrimary theme)
@widgetbook.UseCase(
  name: 'default',
  type: TextButton,
)
Widget useCaseTextButton(BuildContext context) {
  final text = context.knobs.string(
    label: 'Text',
    initialValue: 'Text Button',
  );
  final enabled = context.knobs.boolean(
    label: 'Enabled',
    initialValue: true,
  );

  return TextButton(
    onPressed: enabled ? () {} : null,
    child: Text(text),
  );
}

// TextField Use Cases (has custom AppInputDecorationTheme)
@widgetbook.UseCase(
  name: 'default',
  type: TextField,
)
Widget useCaseTextField(BuildContext context) {
  final labelText = context.knobs.string(
    label: 'Label Text',
    initialValue: 'Enter text',
  );
  final hintText = context.knobs.string(
    label: 'Hint Text',
    initialValue: 'Type something...',
  );
  final enabled = context.knobs.boolean(
    label: 'Enabled',
    initialValue: true,
  );
  final obscureText = context.knobs.boolean(
    label: 'Obscure Text',
    initialValue: false,
  );
  final maxLines = context.knobs.int.slider(
    label: 'Max Lines',
    initialValue: 1,
    min: 1,
    max: 5,
  );

  return TextField(
    enabled: enabled,
    obscureText: obscureText,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: labelText,
      hintText: hintText,
    ),
  );
}
