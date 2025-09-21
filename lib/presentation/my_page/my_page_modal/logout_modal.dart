import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';

Future<void> showLogoutModal(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 277,
            height: 120,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.logOutConfirm,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    fontSize: 18,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ModalButton(
                      width: 118.5,
                      height: 43,
                      backgroundColor: colorScheme.surfaceContainerLow,
                      foregroundColor: colorScheme.outline,
                      label: AppLocalizations.of(context)!.cancel,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    const SizedBox(width: 8),
                    _ModalButton(
                      width: 118.5,
                      height: 43,
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onPrimary,
                      label: AppLocalizations.of(context)!.logOut,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context
                            .read<AuthBloc>()
                            .add(const AuthSignOutPressed());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ModalButton extends StatelessWidget {
  const _ModalButton({
    required this.width,
    required this.height,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
    required this.onPressed,
  });

  final double width;
  final double height;
  final Color backgroundColor;
  final Color foregroundColor;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TextButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(backgroundColor),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          minimumSize: WidgetStateProperty.all(Size(width, height)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          ),
          alignment: Alignment.center,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
            fontSize: 16,
            height: 1.4,
            letterSpacing: 0,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}
