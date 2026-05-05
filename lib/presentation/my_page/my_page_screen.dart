import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/my_page/my_page_modal/delete_user_modal.dart';
import 'package:on_time_front/presentation/my_page/my_page_modal/logout_modal.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.myPageTitle,
            style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        spacing: 12,
        children: [
          _FrameView(
              title: AppLocalizations.of(context)!.myAccount,
              child: _MyAccountView()),
          const _FrameView(
            title: '알람 설정',
            child: _AlarmStatusView(),
          ),
          _FrameView(
            title: AppLocalizations.of(context)!.accountSettings,
            child: Column(
              spacing: 25,
              children: [
                _SettingTile(
                  title: AppLocalizations.of(context)!.logOut,
                  onTap: () async {
                    await showLogoutModal(context);
                  },
                ),
                _SettingTile(
                  title: AppLocalizations.of(context)!.deleteAccount,
                  onTap: () async {
                    final deleteUserModal = DeleteUserModal();
                    await deleteUserModal.showDeleteUserModal(context,
                        onConfirm: () {});
                  },
                ),
              ],
            ),
          ),
          _FrameView(
            title: AppLocalizations.of(context)!.appSettings,
            child: Column(
              spacing: 25,
              children: [
                _SettingTile(
                  title: AppLocalizations.of(context)!.editDefaultPreparation,
                  onTap: () async {
                    final PreparationEntity? updatedPreparation =
                        await context.push('/defaultPreparationSpareTimeEdit');
                    if (updatedPreparation != null) {}
                  },
                ),
                _SettingTile(
                  title: AppLocalizations.of(context)!.allowAppNotifications,
                  onTap: () async {
                    await _handleNotificationPermission(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmStatusView extends StatefulWidget {
  const _AlarmStatusView();

  @override
  State<_AlarmStatusView> createState() => _AlarmStatusViewState();
}

class _AlarmStatusViewState extends State<_AlarmStatusView> {
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _alarmsEnabled = true;
  String _statusLabel = '확인 중';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final alarmRepository = getIt.get<AlarmRepository>();
      final registryRepository = getIt.get<AlarmRegistryRepository>();
      final schedulerService = getIt.get<AlarmSchedulerService>();
      final fallbackService = getIt.get<FallbackAlarmNotificationService>();

      final settings = await alarmRepository.getAlarmSettings();
      final records = await registryRepository.loadAll();
      final capabilities = await schedulerService.getCapabilities();
      final nativePermission = await schedulerService.checkPermission();
      final fallbackPermission = await fallbackService.checkPermission();

      if (!mounted) return;
      setState(() {
        _alarmsEnabled = settings.alarmsEnabled;
        _statusLabel = _buildStatusLabel(
          settings: settings,
          records: records,
          capabilities: capabilities,
          nativePermission: nativePermission,
          fallbackPermission: fallbackPermission,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusLabel = '상태를 불러올 수 없음';
        _isLoading = false;
      });
    }
  }

  String _buildStatusLabel({
    required AlarmSettings settings,
    required List<ScheduledAlarmRecord> records,
    required AlarmSchedulerCapabilities capabilities,
    required AlarmPermissionState nativePermission,
    required AlarmPermissionState fallbackPermission,
  }) {
    if (!settings.alarmsEnabled) return '꺼짐';
    if (records.any((record) =>
        record.provider == AlarmProvider.androidAlarmManager ||
        record.provider == AlarmProvider.iosAlarmKit)) {
      return '네이티브 알람';
    }
    if (records
        .any((record) => record.provider == AlarmProvider.localNotification)) {
      return '알림 대체';
    }
    if (capabilities.supportsNativeAlarm &&
        nativePermission != AlarmPermissionState.granted &&
        fallbackPermission != AlarmPermissionState.granted) {
      return '권한 필요';
    }
    if (!capabilities.supportsNativeAlarm &&
        fallbackPermission != AlarmPermissionState.granted) {
      return '지원 안 됨';
    }
    return '대기 중';
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _isUpdating = true;
      _alarmsEnabled = value;
    });
    try {
      final alarmRepository = getIt.get<AlarmRepository>();
      await alarmRepository.updateAlarmSettings(alarmsEnabled: value);
      if (value) {
        final schedulerService = getIt.get<AlarmSchedulerService>();
        final fallbackService = getIt.get<FallbackAlarmNotificationService>();
        final nativePermission = await schedulerService.requestPermission();
        if (nativePermission != AlarmPermissionState.granted) {
          await fallbackService.requestPermission();
        }
        await getIt.get<ReconcileAlarmsUseCase>()();
      } else {
        await getIt.get<CancelAllAlarmsUseCase>()();
      }
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('일정 알람', style: textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              _isLoading ? '확인 중' : _statusLabel,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
        Switch(
          value: _alarmsEnabled,
          onChanged: _isUpdating ? null : _toggle,
        ),
      ],
    );
  }
}

class _MyAccountView extends StatelessWidget {
  const _MyAccountView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          final user = state.user.mapOrNull(
            (user) => user,
            empty: (_) => null,
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0) +
                EdgeInsets.only(bottom: 9),
            child: Row(
              spacing: 20,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: Image.asset(
                    'profile.png',
                    package: 'assets',
                  ).image,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user!.name, style: textTheme.titleMedium),
                    Text(user.email,
                        style: textTheme.bodyMedium!.copyWith(
                          color: colorScheme.outline,
                        )),
                  ],
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _FrameView extends StatelessWidget {
  const _FrameView({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 25,
          children: [
            Text(title,
                style:
                    textTheme.bodyMedium!.copyWith(color: colorScheme.outline)),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: textTheme.bodyLarge),
          Icon(Icons.arrow_forward_ios,
              size: 16, color: colorScheme.outlineVariant),
        ],
      ),
    );
  }
}

Future<void> _handleNotificationPermission(BuildContext context) async {
  final notificationService = NotificationService.instance;
  final currentStatus = await notificationService.checkNotificationPermission();

  if (!context.mounted) return;

  if (currentStatus == AuthorizationStatus.authorized) {
    await _showAlreadyEnabledDialog(context);
  } else if (currentStatus == AuthorizationStatus.denied) {
    final shouldRequest = await _showPermissionRationaleDialog(context);
    if (shouldRequest == true && context.mounted) {
      final newStatus = await notificationService.requestPermission();

      if (!context.mounted) return;

      if (newStatus == AuthorizationStatus.authorized) {
        await notificationService.initialize();
        if (!context.mounted) return;
        await _showPermissionGrantedDialog(context);
      } else if (newStatus == AuthorizationStatus.denied) {
        await _showGoToSettingsDialog(context);
      }
    }
  } else if (currentStatus == AuthorizationStatus.notDetermined) {
    final shouldRequest = await _showPermissionRationaleDialog(context);
    if (shouldRequest == true && context.mounted) {
      final newStatus = await notificationService.requestPermission();

      if (!context.mounted) return;

      if (newStatus == AuthorizationStatus.authorized) {
        await notificationService.initialize();
        if (!context.mounted) return;
        await _showPermissionGrantedDialog(context);
      } else if (newStatus == AuthorizationStatus.denied) {
        await _showGoToSettingsDialog(context);
      }
    }
  } else {
    await _showGoToSettingsDialog(context);
  }
}

Future<void> _showAlreadyEnabledDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;

  await showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: l10n.notificationAlreadyEnabled,
      description: l10n.notificationAlreadyEnabledDescription,
      primaryAction: DialogActionConfig(
        label: l10n.ok,
        variant: ModalWideButtonVariant.primary,
      ),
    ),
  );
}

Future<bool?> _showPermissionRationaleDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;

  final result = await showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: l10n.notificationPermissionRequired,
      description: l10n.notificationPermissionRequiredDescription,
      secondaryAction: DialogActionConfig(
        label: l10n.cancel,
        variant: ModalWideButtonVariant.neutral,
      ),
      primaryAction: DialogActionConfig(
        label: l10n.allow,
        variant: ModalWideButtonVariant.primary,
      ),
    ),
  );

  return result == DialogActionResult.primary;
}

Future<void> _showPermissionGrantedDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;

  await showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: l10n.notificationPermissionGranted,
      description: l10n.notificationPermissionGrantedDescription,
      primaryAction: DialogActionConfig(
        label: l10n.ok,
        variant: ModalWideButtonVariant.primary,
      ),
    ),
  );
}

Future<void> _showGoToSettingsDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;

  final result = await showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: l10n.openNotificationSettings,
      description: l10n.openNotificationSettingsDescription,
      secondaryAction: DialogActionConfig(
        label: l10n.cancel,
        variant: ModalWideButtonVariant.neutral,
      ),
      primaryAction: DialogActionConfig(
        label: l10n.openSettings,
        variant: ModalWideButtonVariant.primary,
      ),
    ),
  );

  if (result == DialogActionResult.primary) {
    await NotificationService.instance.openNotificationSettings();
  }
}
