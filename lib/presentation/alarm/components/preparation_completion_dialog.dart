import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

Future<void> showPreparationCompletionDialog({
  required BuildContext context,
  required VoidCallback onFinish,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return CustomAlertDialog(
        title: Text(
          AppLocalizations.of(dialogContext)!.areYouRunningLate,
        ),
        content: Text(
          AppLocalizations.of(dialogContext)!.runningLateDescription,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          ModalButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            text: AppLocalizations.of(dialogContext)!.continuePreparing,
            color: Theme.of(dialogContext).colorScheme.primaryContainer,
            textColor: Theme.of(dialogContext).colorScheme.primary,
          ),
          ModalButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onFinish();
            },
            text: AppLocalizations.of(dialogContext)!.finishPreparation,
            color: Theme.of(dialogContext).colorScheme.primary,
            textColor: Theme.of(dialogContext).colorScheme.surface,
          ),
        ],
      );
    },
  );
}
