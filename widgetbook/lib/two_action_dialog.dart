import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/dialog_story_helpers.dart';

@widgetbook.UseCase(
  name: 'Destructive Two Action',
  type: TwoActionDialog,
)
Widget destructiveTwoActionDialogUseCase(BuildContext context) {
  final title = context.knobs.string(
    label: 'Title',
    initialValue: '정말 약속을 삭제할까요?',
  );
  final description = context.knobs.string(
    label: 'Description',
    initialValue: '약속을 삭제하면 다시 되돌릴 수 없어요.',
  );

  return DialogStoryBackdrop(
    child: TwoActionDialog(
      config: TwoActionDialogConfig(
        title: title,
        description: description,
        secondaryAction: const DialogActionConfig(
          label: '취소',
          variant: ModalWideButtonVariant.neutral,
        ),
        primaryAction: const DialogActionConfig(
          label: '약속 삭제',
          variant: ModalWideButtonVariant.destructive,
        ),
      ),
      onPrimaryPressed: () {},
      onSecondaryPressed: () {},
    ),
  );
}

@widgetbook.UseCase(
  name: 'Single Primary',
  type: TwoActionDialog,
)
Widget singlePrimaryDialogUseCase(BuildContext context) {
  final title = context.knobs.string(
    label: 'Title',
    initialValue: '알림 허용 완료',
  );
  final description = context.knobs.string(
    label: 'Description',
    initialValue: '알림이 성공적으로 활성화되었습니다.',
  );

  return DialogStoryBackdrop(
    child: TwoActionDialog(
      config: TwoActionDialogConfig(
        title: title,
        description: description,
        primaryAction: const DialogActionConfig(
          label: '확인',
          variant: ModalWideButtonVariant.primary,
        ),
      ),
      onPrimaryPressed: () {},
    ),
  );
}
