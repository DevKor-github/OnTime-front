import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_error_button.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: CustomAlertDialog,
)
Widget customAlertDialog(BuildContext context) {
  final titleText = context.knobs.string(
    label: 'Dialog Title',
    initialValue: '정말 나가시겠어요?',
  );

  final contentText = context.knobs.string(
    label: 'Dilog Content',
    initialValue: '이 화면을 나가면\n함께 약속을 준비할 수 없게 돼요',
  );

  return Container(
    height: double.infinity,
    width: double.infinity,
    color: Colors.black.withValues(
      alpha: 0.4,
    ),
    child: CustomAlertDialog(
      title: Text(
        titleText,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
      content: Text(
        contentText,
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      alignment: Alignment.center,
      actions: [
        ModalButton(
          onPressed: () {},
          text: '나갈래요',
          color: Theme.of(context).colorScheme.surfaceContainer,
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
        ModalButton(
          onPressed: () {},
          text: '있을게요',
          color: Theme.of(context).colorScheme.primary,
          textColor: Theme.of(context).colorScheme.surface,
        )
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Error',
  type: CustomAlertDialog,
)
Widget errorCusmtomAlertDialog(BuildContext context) {
  final titleText = context.knobs.string(
    label: 'Dialog Title',
    initialValue: '다 챙기셨나요?',
  );

  final contentText = context.knobs.string(
    label: 'Dolog Content',
    initialValue: '아직 챙기지 않은 것들이 있어요.',
  );

  return Container(
    height: double.infinity,
    width: double.infinity,
    color: Colors.black.withValues(
      alpha: 0.4,
    ),
    child: CustomAlertDialog.error(
      title: Text(
        titleText,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
      content: Text(
        contentText,
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      alignment: Alignment.center,
      actions: [
        ModalErrorButton(
          onPressed: () {},
          text: '확인',
          color: Theme.of(context).colorScheme.error,
          textColor: Theme.of(context).colorScheme.surface,
        )
      ],
    ),
  );
}
