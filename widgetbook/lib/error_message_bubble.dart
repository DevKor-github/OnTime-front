import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/error_message_bubble.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: ErrorMessageBubble,
)
Widget useCaseCheckButton(BuildContext context) {
  final errorMessage = context.knobs.string(
    label: 'Error Message',
    initialValue: '여유시간은 10분 아래로 설정할 수 없어요 ',
  );
  final action =
      context.knobs.boolean(label: 'Action Button', initialValue: true);
  final tailposition = context.knobs.list(label: 'Tail Position', options: [
    TailPosition.top,
    TailPosition.bottom,
  ]);
  return ErrorMessageBubble(
    errorMessage: Text(
      errorMessage,
    ),
    action: action
        ? TextButton(
            onPressed: () {},
            child: const Text(
              '확인',
              style: TextStyle(
                decoration: TextDecoration.underline,
              ),
            ),
          )
        : null,
    tailPosition: tailposition,
  );
}
