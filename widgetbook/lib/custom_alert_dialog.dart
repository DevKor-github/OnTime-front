import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/dialog_story_helpers.dart';

@widgetbook.UseCase(
  name: 'Primitive',
  type: CustomAlertDialog,
)
Widget customAlertDialogPrimitiveUseCase(BuildContext context) {
  final titleText = context.knobs.string(
    label: 'Dialog Title',
    initialValue: '정말 나가시겠어요?',
  );

  final contentText = context.knobs.string(
    label: 'Dialog Content',
    initialValue: '이 화면을 나가면\n함께 약속을 준비할 수 없게 돼요',
  );

  final centerText = context.knobs.boolean(
    label: 'Center Text',
    initialValue: false,
  );

  return DialogStoryBackdrop(
    child: CustomAlertDialog(
      title: Text(titleText, style: const TextStyle(fontSize: 16)),
      content: Text(contentText),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      alignment: Alignment.center,
      titleTextAlign: centerText ? TextAlign.center : TextAlign.start,
      contentTextAlign: centerText ? TextAlign.center : TextAlign.start,
      titleContentSpacing: centerText ? 6.0 : null,
      contentActionsSpacing: 16.0,
      actions: [
        _buildActionButton(
          text: '취소',
          variant: ModalWideButtonVariant.neutral,
          width: 114,
        ),
        _buildActionButton(
          text: '확인',
          variant: ModalWideButtonVariant.primary,
          width: 114,
        ),
      ],
    ),
  );
}

Widget _buildActionButton({
  required String text,
  required ModalWideButtonVariant variant,
  required double width,
  double height = 43,
}) {
  return SizedBox(
    width: width,
    child: ModalWideButton(
      onPressed: () {},
      text: text,
      variant: variant,
      layout: ModalWideButtonLayout.full,
      height: height,
    ),
  );
}
