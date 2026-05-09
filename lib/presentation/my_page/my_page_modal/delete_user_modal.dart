import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/validation/backend_constraints.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/delete_user_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_button_delete_dialog.dart';

class DeleteUserModal {
  DeleteUserModal({
    DeleteUserUseCase? deleteUserUseCase,
    UserRepository? userRepository,
  }) : _deleteUserUseCase = deleteUserUseCase,
       _userRepository = userRepository;

  final DeleteUserUseCase? _deleteUserUseCase;
  final UserRepository? _userRepository;

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
    BuildContext context,
    VoidCallback onConfirm,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _DeleteFeedbackDialog(
          onDelete: (feedbackMessage) async {
            await _deleteAccount(feedbackMessage);
          },
        );
      },
    );

    if (result == true) {
      onConfirm();
    }
  }

  Future<void> _deleteAccount(String feedbackMessage) async {
    final deleteUserUseCase = _deleteUserUseCase ?? getIt<DeleteUserUseCase>();
    await deleteUserUseCase(feedbackMessage);

    try {
      final userRepository = _userRepository ?? getIt<UserRepository>();
      await userRepository.signOut();
    } catch (error) {
      AppLogger.debug(
        'Sign out after delete user failed errorType=${error.runtimeType}',
      );
    }
  }
}

class _DeleteFeedbackDialog extends StatefulWidget {
  const _DeleteFeedbackDialog({required this.onDelete});

  final Future<void> Function(String feedbackMessage) onDelete;

  @override
  State<_DeleteFeedbackDialog> createState() => _DeleteFeedbackDialogState();
}

class _DeleteFeedbackDialogState extends State<_DeleteFeedbackDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = (screenWidth - 32).clamp(0.0, 277.0).toDouble();

    return PopScope(
      canPop: !_isDeleting,
      child: CustomAlertDialog(
        title: Text(
          l10n.deleteFeedbackTitle,
          style: textTheme.titleMedium?.copyWith(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            height: 1.4,
            color: colorScheme.onSurface,
          ),
        ),
        innerPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        titleContentSpacing: 8,
        contentActionsSpacing: 16,
        content: Column(
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
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_isDeleting,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    BackendConstraints.maxLongTextLength,
                  ),
                ],
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
                  hintText: _focusNode.hasFocus
                      ? ''
                      : l10n.deleteFeedbackPlaceholder,
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
                  disabledBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: dialogWidth,
            child: Row(
              children: [
                ModalWideButton(
                  layout: ModalWideButtonLayout.flex,
                  text: l10n.keepUsingLong,
                  variant: ModalWideButtonVariant.neutral,
                  textStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.4,
                    color: colorScheme.outline,
                  ),
                  height: 43,
                  onPressed: _isDeleting
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 8),
                ModalWideButton(
                  layout: ModalWideButtonLayout.flex,
                  text: l10n.sendFeedbackAndDelete,
                  variant: ModalWideButtonVariant.destructive,
                  textStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.4,
                    color: colorScheme.onError,
                  ),
                  height: 43,
                  isLoading: _isDeleting,
                  onPressed: _submitDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDelete() async {
    if (_isDeleting) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.onDelete(_controller.text);
    } catch (error) {
      AppLogger.debug('Delete user failed errorType=${error.runtimeType}');
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error)),
      );
      setState(() {
        _isDeleting = false;
      });
      return;
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
