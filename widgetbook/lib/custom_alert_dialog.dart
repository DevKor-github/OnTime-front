import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/shared/theme/theme.dart';

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
      ),
      content: Text(
        contentText,
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      alignment: Alignment.center,
      actions: [
        FilledButton(
          onPressed: () {},
          child: const Text(
            '나갈래',
          ),
        ),
        FilledButton(
          onPressed: () {},
          child: const Text(
            '있을래',
          ),
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
      ),
      content: Text(
        contentText,
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      alignment: Alignment.center,
      actions: [
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text(
            '확인',
          ),
        ),
      ],
    ),
  );
}
