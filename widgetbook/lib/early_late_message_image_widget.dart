import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/early_late/components/early_late_message_image_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Default',
  type: EarlyLateMessageImageWidget,
)
Widget earlyLateMessageImageWidgetUseCase(BuildContext context) {
  final message = context.knobs.string(
    label: 'Message',
    initialValue: '지금 출발하면 늦지 않아요!',
  );

  final screenHeight = MediaQuery.of(context).size.height;

  return EarlyLateMessageImageWidget(
    screenHeight: screenHeight,
    earlylateMessage: message,
  );
}
