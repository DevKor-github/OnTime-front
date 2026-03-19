import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';

Future<bool?> showTwoButtonDeleteDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String cancelText,
  required String confirmText,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final textTheme = theme.textTheme;
      final colorScheme = theme.colorScheme;

      final screenWidth = MediaQuery.sizeOf(ctx).width;
      final dialogWidth = (screenWidth - 32).clamp(0.0, 277.0);

      return CustomAlertDialog.error(
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            height: 1.4,
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          description,
          style: textTheme.bodyMedium?.copyWith(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.4,
            color: colorScheme.outline,
          ),
        ),
        actions: [
          SizedBox(
            width: dialogWidth,
            child: Row(
              children: [
                ModalWideButton(
                  isFlexible: true,
                  text: cancelText,
                  color: colorScheme.surfaceContainerLow,
                  textColor: colorScheme.outline,
                  textStyle: textTheme.titleSmall?.copyWith(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.4,
                    color: colorScheme.outline,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                const SizedBox(width: 8),
                ModalWideButton(
                  isFlexible: true,
                  text: confirmText,
                  color: colorScheme.error,
                  textColor: colorScheme.onError,
                  textStyle: textTheme.titleSmall?.copyWith(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.4,
                    color: colorScheme.onError,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        innerPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        titleContentSpacing: 8,
        contentActionsSpacing: 16,
      );
    },
  );
}
