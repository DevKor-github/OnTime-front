import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

Future<void> showPreparationCompletionDialog({
  required BuildContext context,
  required VoidCallback onFinish,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: l10n.areYouRunningLate,
      description: l10n.runningLateDescription,
      barrierDismissible: false,
      secondaryAction: DialogActionConfig(
        label: l10n.continuePreparing,
        variant: ModalWideButtonVariant.neutral,
      ),
      primaryAction: DialogActionConfig(
        label: l10n.finishPreparation,
        variant: ModalWideButtonVariant.primary,
      ),
    ),
  );

  if (result == DialogActionResult.primary) {
    onFinish();
  }
}
