import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/early_late/components/check_list_box_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: CheckListBoxWidget,
)
Widget checkListBoxWidgetUseCase(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  final checkList = ['지갑 챙기기', '문 잠그기', '우산 챙기기'];
  final checkStates = List.generate(
    checkList.length,
    (index) => context.knobs.boolean(
      label: '${checkList[index]} 체크됨',
      initialValue: false,
    ),
  );

  return CheckListBoxWidget(
    screenWidth: screenWidth,
    screenHeight: screenHeight,
    checkList: checkList,
    checkedStates: checkStates,
    onItemToggled: (_) {},
  );
}
