import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';

enum DialogActionResult {
  primary,
  secondary,
  dismissed,
}

class DialogActionConfig {
  const DialogActionConfig({
    required this.label,
    this.variant = ModalWideButtonVariant.neutral,
    this.textStyle,
  });

  final String label;
  final ModalWideButtonVariant variant;
  final TextStyle? textStyle;
}

class TwoActionDialogConfig {
  const TwoActionDialogConfig({
    required this.title,
    this.description,
    required this.primaryAction,
    this.secondaryAction,
    this.barrierDismissible = true,
    this.maxWidth = TwoActionDialogTokens.maxDialogWidth,
    this.innerPadding = TwoActionDialogTokens.innerPadding,
    this.titleContentSpacing = TwoActionDialogTokens.titleContentSpacing,
    this.contentActionsSpacing = TwoActionDialogTokens.contentActionsSpacing,
  });

  final String title;
  final String? description;
  final DialogActionConfig primaryAction;
  final DialogActionConfig? secondaryAction;
  final bool barrierDismissible;
  final double maxWidth;
  final EdgeInsets innerPadding;
  final double titleContentSpacing;
  final double contentActionsSpacing;
}

abstract final class TwoActionDialogTokens {
  static const double maxDialogWidth = 277;
  static const EdgeInsets innerPadding = EdgeInsets.fromLTRB(16, 18, 16, 18);
  static const double titleContentSpacing = 8;
  static const double contentActionsSpacing = 16;
  static const double actionButtonHeight = 43;
  static const double actionSpacing = 8;

  const TwoActionDialogTokens._();
}

Future<DialogActionResult> showTwoActionDialog(
  BuildContext context, {
  required TwoActionDialogConfig config,
  Widget? customContent,
}) async {
  final result = await showDialog<DialogActionResult>(
    context: context,
    barrierDismissible: config.barrierDismissible,
    builder: (dialogContext) {
      return TwoActionDialog(
        config: config,
        customContent: customContent,
        onPrimaryPressed: () =>
            Navigator.of(dialogContext).pop(DialogActionResult.primary),
        onSecondaryPressed: config.secondaryAction == null
            ? null
            : () =>
                Navigator.of(dialogContext).pop(DialogActionResult.secondary),
      );
    },
  );

  return result ?? DialogActionResult.dismissed;
}

class TwoActionDialog extends StatelessWidget {
  const TwoActionDialog({
    super.key,
    required this.config,
    this.customContent,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
  });

  final TwoActionDialogConfig config;
  final Widget? customContent;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = (screenWidth - 32).clamp(0.0, config.maxWidth);

    final titleText = Text(
      config.title,
      style: textTheme.titleMedium?.copyWith(
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w600,
        fontSize: 18,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
    );

    final bodyContent = customContent ??
        (config.description == null
            ? null
            : Text(
                config.description!,
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.4,
                  color: colorScheme.outline,
                ),
              ));

    return CustomAlertDialog.error(
      title: titleText,
      content: bodyContent,
      actions: [
        SizedBox(
          width: dialogWidth,
          child: Row(
            children: [
              if (config.secondaryAction != null) ...[
                ModalWideButton(
                  layout: ModalWideButtonLayout.flex,
                  text: config.secondaryAction!.label,
                  variant: config.secondaryAction!.variant,
                  textStyle: config.secondaryAction!.textStyle,
                  height: TwoActionDialogTokens.actionButtonHeight,
                  onPressed: onSecondaryPressed,
                ),
                const SizedBox(width: TwoActionDialogTokens.actionSpacing),
              ],
              ModalWideButton(
                layout: ModalWideButtonLayout.flex,
                text: config.primaryAction.label,
                variant: config.primaryAction.variant,
                textStyle: config.primaryAction.textStyle,
                height: TwoActionDialogTokens.actionButtonHeight,
                onPressed: onPrimaryPressed,
              ),
            ],
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
      innerPadding: config.innerPadding,
      titleContentSpacing: config.titleContentSpacing,
      contentActionsSpacing: config.contentActionsSpacing,
    );
  }
}
