import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/early_late/components/check_list_item_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: ChecklistItemWidget,
)
Widget checklistItemWidgetUseCase(BuildContext context) {
  final label = context.knobs.string(label: 'Label', initialValue: '우산 챙기기');
  final isChecked =
      context.knobs.boolean(label: 'Checked', initialValue: false);

  return ChecklistItemWidget(
    index: 0,
    label: label,
    isChecked: isChecked,
    onToggle: () {},
  );
}
