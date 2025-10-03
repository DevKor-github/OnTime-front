import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';

Future<void> showLogoutModal(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return CustomAlertDialog.error(
        title: Text(
          AppLocalizations.of(context)!.logOutConfirm,
          style: textTheme.titleMedium?.copyWith(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            height: 1.4,
            fontSize: 18,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          ModalButton(
            text: AppLocalizations.of(context)!.cancel,
            color: colorScheme.surfaceContainerLow,
            textColor: colorScheme.outline,
            textStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.normal,
              fontSize: 16,
              height: 1.4,
              letterSpacing: 0,
              color: colorScheme.outline,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: 8),
          ModalButton(
            text: AppLocalizations.of(context)!.logOut,
            color: colorScheme.error,
            textColor: colorScheme.onPrimary,
            textStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.normal,
              fontSize: 16,
              height: 1.4,
              letterSpacing: 0,
              color: colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(const AuthSignOutPressed());
            },
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        innerPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      );
    },
  );
}

