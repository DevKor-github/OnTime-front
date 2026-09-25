import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

Future<void> showPreparationCompletionDialog({
  required BuildContext context,
  required bool isLate,
  required VoidCallback onFinish,
  VoidCallback? onContinue,
  bool manual = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: manual
          ? l10n.finishPreparationConfirmTitle
          : isLate
          ? l10n.areYouRunningLate
          : l10n.preparationCompletedTitle,
      description: manual
          ? l10n.finishPreparationConfirmDescription
          : isLate
          ? l10n.runningLateDescription
          : l10n.preparationCompletedDescription,
      barrierDismissible: false,
      useSafeArea: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      innerPadding: const EdgeInsets.all(16),
      titleContentSpacing: 12,
      contentActionsSpacing: 12,
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
  } else if (result == DialogActionResult.secondary) {
    onContinue?.call();
  }
}
