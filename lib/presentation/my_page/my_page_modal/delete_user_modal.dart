import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/use-cases/delete_user_use_case.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';

class DeleteUserModal {
  Future<void> showDeleteUserModal(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return CustomAlertDialog.error(
          title: Text(
            AppLocalizations.of(context)!.deleteAccountConfirmTitle,
            style: textTheme.titleMedium?.copyWith(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              height: 1.4,
              fontSize: 18,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            AppLocalizations.of(context)!.deleteAccountConfirmDescription,
            style: textTheme.bodyMedium?.copyWith(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              height: 1.4,
              fontSize: 14,
              color: colorScheme.outline,
            ),
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModalWideButton(
                  text: AppLocalizations.of(context)!.keepUsing,
                  color: colorScheme.surfaceContainerLow,
                  textColor: colorScheme.outline,
                  textStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.4,
                    color: colorScheme.outline,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                const SizedBox(height: 8),
                ModalWideButton(
                  text: AppLocalizations.of(context)!.deleteAnyway,
                  color: colorScheme.error,
                  textColor: colorScheme.onPrimary,
                  textStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.4,
                    color: colorScheme.onPrimary,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showDeleteFeedbackModal(context, onConfirm);
                  },
                ),
              ],
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
          innerPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        );
      },
    );
  }

  Future<void> _showDeleteFeedbackModal(
      BuildContext context, VoidCallback onConfirm) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final controller = TextEditingController();
        final focusNode = FocusNode();
        return CustomAlertDialog.error(
          title: Text(
            AppLocalizations.of(context)!.deleteFeedbackTitle,
            style: textTheme.titleMedium?.copyWith(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              height: 1.4,
              fontSize: 18,
              color: colorScheme.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.deleteFeedbackDescription,
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  fontSize: 14,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 249,
                height: 160,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.outlineVariant, width: 1),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: null,
                  expands: true,
                  textAlign: TextAlign.start,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: colorScheme.outline,
                  style: textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: focusNode.hasFocus
                        ? ''
                        : AppLocalizations.of(context)!
                            .deleteFeedbackPlaceholder,
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      fontSize: 14,
                      color: colorScheme.outlineVariant,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModalWideButton(
                  text: AppLocalizations.of(context)!.keepUsingLong,
                  color: colorScheme.surfaceContainerLow,
                  textColor: colorScheme.outline,
                  textStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.4,
                    color: colorScheme.outline,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                const SizedBox(height: 8),
                ModalWideButton(
                  text: AppLocalizations.of(context)!.sendFeedbackAndDelete,
                  color: colorScheme.error,
                  textColor: colorScheme.onPrimary,
                  textStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.4,
                    color: colorScheme.onPrimary,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();

                    try {
                      final deleteUserUseCase = getIt<DeleteUserUseCase>();
                      await deleteUserUseCase(controller.text);
                    } catch (e) {
                      debugPrint(e.toString());
                    }

                    try {
                      final userRepository = getIt<UserRepository>();
                      await userRepository.signOut();
                    } catch (e) {
                      debugPrint(e.toString());
                    }

                    onConfirm();
                  },
                ),
              ],
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
          innerPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        );
      },
    );
  }
}
