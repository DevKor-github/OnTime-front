import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/cubit/notification_gate_cubit.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

abstract interface class NotificationPermissionGateway {
  Future<AuthorizationStatus> checkNotificationPermission();

  Future<AuthorizationStatus> requestPermission();

  Future<bool> openNotificationSettings();
}

class NotificationServicePermissionGateway
    implements NotificationPermissionGateway {
  const NotificationServicePermissionGateway();

  @override
  Future<AuthorizationStatus> checkNotificationPermission() {
    return NotificationService.instance.checkNotificationPermission();
  }

  @override
  Future<bool> openNotificationSettings() {
    return NotificationService.instance.openNotificationSettings();
  }

  @override
  Future<AuthorizationStatus> requestPermission() {
    return NotificationService.instance.requestPermission();
  }
}

class NotificationAllowScreen extends StatefulWidget {
  const NotificationAllowScreen({
    super.key,
    this.permissionGateway = const NotificationServicePermissionGateway(),
  });

  final NotificationPermissionGateway permissionGateway;

  @override
  State<NotificationAllowScreen> createState() =>
      _NotificationAllowScreenState();
}

class _NotificationAllowScreenState extends State<NotificationAllowScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _continueIfPermissionAllowed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _continueIfPermissionAllowed() async {
    final currentStatus = await widget.permissionGateway
        .checkNotificationPermission();
    if (!mounted || currentStatus != AuthorizationStatus.authorized) {
      return;
    }

    await context.read<NotificationGateCubit>().markPermissionAllowed();
    if (!mounted) return;
    context.go('/home');
  }

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
                  children: [_Image(), _Title()],
                ),
              ),
            ),
            _Buttons(permissionGateway: widget.permissionGateway),
          ],
        ),
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.permissionGateway});

  final NotificationPermissionGateway permissionGateway;

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
            await _handleNotificationPermission(context, permissionGateway);
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
          onTap: () async {
            await context.read<NotificationGateCubit>().dismissPrompt();
            if (!context.mounted) return;
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
          style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
        ),
        SizedBox(
          width: 282,
          child: Text(
            AppLocalizations.of(context)!.notificationPermissionDescription,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: colorScheme.outline),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
      ),
      child: SvgPicture.asset(
        'bell-ringing.svg',
        package: 'assets',
        colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
      ),
    );
  }
}

Future<void> _handleNotificationPermission(
  BuildContext context,
  NotificationPermissionGateway permissionGateway,
) async {
  final currentStatus = await permissionGateway.checkNotificationPermission();

  if (!context.mounted) return;

  if (currentStatus == AuthorizationStatus.authorized) {
    await context.read<NotificationGateCubit>().markPermissionAllowed();
    if (context.mounted) {
      context.go('/home');
    }
  } else {
    final newStatus = await permissionGateway.requestPermission();

    if (!context.mounted) return;

    if (newStatus == AuthorizationStatus.authorized) {
      await context.read<NotificationGateCubit>().markPermissionAllowed();
      if (context.mounted) {
        context.go('/home');
      }
    } else {
      await context.read<NotificationGateCubit>().dismissPrompt();
      if (context.mounted) {
        context.go('/home');
      }
    }
  }
}
