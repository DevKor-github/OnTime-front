import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class NotificationAllowScreen extends StatelessWidget {
  const NotificationAllowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(bottom: 72.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 68.50,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 40,
                  children: [
                    _Image(),
                    _Title(),
                  ],
                ),
              ),
            ),
            _Buttons(),
          ],
        ),
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 24,
      children: [
        FilledButton(
          onPressed: () async {
            await _handleNotificationPermission(context);
          },
          child: Text(
            AppLocalizations.of(context)!.allowNotifications,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            context.go('/home');
          },
          child: SizedBox(
            width: 358,
            child: Text(
              AppLocalizations.of(context)!.doItLater,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.grey[400],
                decoration: TextDecoration.underline,
                decorationColor: AppColors.grey[400],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12,
      children: [
        Text(
          AppLocalizations.of(context)!.pleaseAllowNotifications,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.primary,
          ),
        ),
        SizedBox(
          width: 282,
          child: Text(
            AppLocalizations.of(context)!.notificationPermissionDescription,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _Image extends StatelessWidget {
  const _Image();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 70,
      height: 70,
      padding: const EdgeInsets.all(17.50),
      decoration: ShapeDecoration(
        color: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(35),
        ),
      ),
      child: SvgPicture.asset(
        'bell-ringing.svg',
        package: 'assets',
        colorFilter: ColorFilter.mode(
          colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

Future<void> _handleNotificationPermission(BuildContext context) async {
  final notificationService = NotificationService.instance;
  final currentStatus = await notificationService.checkNotificationPermission();

  if (!context.mounted) return;

  if (currentStatus == AuthorizationStatus.authorized) {
    await notificationService.initialize();
    if (context.mounted) {
      context.go('/home');
    }
  } else if (currentStatus == AuthorizationStatus.denied) {
    final shouldOpenSettings = await _showGoToSettingsDialog(context);
    if (shouldOpenSettings == true) {
      await notificationService.openNotificationSettings();
    }
  } else if (currentStatus == AuthorizationStatus.notDetermined) {
    final newStatus = await notificationService.requestPermission();

    if (!context.mounted) return;

    if (newStatus == AuthorizationStatus.authorized) {
      await notificationService.initialize();
      if (context.mounted) {
        context.go('/home');
      }
    } else if (newStatus == AuthorizationStatus.denied) {
      final shouldOpenSettings = await _showGoToSettingsDialog(context);
      if (shouldOpenSettings == true) {
        await notificationService.openNotificationSettings();
      }
    }
  } else {
    final shouldOpenSettings = await _showGoToSettingsDialog(context);
    if (shouldOpenSettings == true) {
      await notificationService.openNotificationSettings();
    }
  }
}

Future<bool?> _showGoToSettingsDialog(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final l10n = AppLocalizations.of(context)!;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CustomAlertDialog(
      title: Text(l10n.openNotificationSettings),
      content: Text(l10n.openNotificationSettingsDescription),
      actions: [
        ModalButton(
          onPressed: () => Navigator.of(context).pop(false),
          text: l10n.doItLater,
          color: colorScheme.surfaceContainerHighest,
          textStyle: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        ModalButton(
          onPressed: () => Navigator.of(context).pop(true),
          text: l10n.openSettings,
          color: colorScheme.primary,
          textStyle: textTheme.titleSmall?.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
      ],
    ),
  );
}
