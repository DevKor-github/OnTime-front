import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

Future<bool?> showTwoButtonDeleteDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String cancelText,
  required String confirmText,
  bool barrierDismissible = true,
}) async {
  final result = await showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: title,
      description: description,
      barrierDismissible: barrierDismissible,
      secondaryAction: DialogActionConfig(
        label: cancelText,
        variant: ModalWideButtonVariant.neutral,
      ),
      primaryAction: DialogActionConfig(
        label: confirmText,
        variant: ModalWideButtonVariant.destructive,
      ),
    ),
  );

  return switch (result) {
    DialogActionResult.primary => true,
    DialogActionResult.secondary => false,
    DialogActionResult.dismissed => null,
  };
}
