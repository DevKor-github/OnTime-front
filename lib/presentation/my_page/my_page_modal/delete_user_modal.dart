import 'package:flutter/material.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/delete_user_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/components/two_button_delete_dialog.dart';

class DeleteUserModal {
  Future<void> showDeleteUserModal(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    final shouldDelete = await showTwoButtonDeleteDialog(
      context,
      title: l10n.deleteAccountConfirmTitle,
      description: l10n.deleteAccountConfirmDescription,
      cancelText: l10n.keepUsing,
      confirmText: l10n.deleteAnyway,
    );

    if (shouldDelete == true && context.mounted) {
      await _showDeleteFeedbackModal(context, onConfirm);
    }
  }

  Future<void> _showDeleteFeedbackModal(
      BuildContext context, VoidCallback onConfirm) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final controller = TextEditingController();
    final focusNode = FocusNode();

    final result = await showTwoActionDialog(
      context,
      config: TwoActionDialogConfig(
        title: l10n.deleteFeedbackTitle,
        secondaryAction: DialogActionConfig(
          label: l10n.keepUsingLong,
          variant: ModalWideButtonVariant.neutral,
          textStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.4,
            color: colorScheme.outline,
          ),
        ),
        primaryAction: DialogActionConfig(
          label: l10n.sendFeedbackAndDelete,
          variant: ModalWideButtonVariant.destructive,
          textStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.4,
            color: colorScheme.onError,
          ),
        ),
      ),
      customContent: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.deleteFeedbackDescription,
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
              border: Border.all(color: colorScheme.outlineVariant, width: 1),
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
                hintText:
                    focusNode.hasFocus ? '' : l10n.deleteFeedbackPlaceholder,
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
    );

    if (result != DialogActionResult.primary) {
      return;
    }

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
  }
}
