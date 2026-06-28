import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:on_time_front/core/constants/external_links.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_delivery_policy.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/cubit/analytics_preference_cubit.dart';
import 'package:on_time_front/presentation/my_page/my_page_modal/delete_user_modal.dart';
import 'package:on_time_front/presentation/my_page/my_page_modal/logout_modal.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

typedef PrivacyPolicyLauncher = Future<bool> Function(Uri uri);

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({
    super.key,
    PrivacyPolicyLauncher? openPrivacyPolicy,
    NotificationService? notificationService,
    AnalyticsPreferenceCubit? analyticsPreferenceCubit,
  }) : _openPrivacyPolicy = openPrivacyPolicy,
       _notificationService = notificationService,
       _analyticsPreferenceCubit = analyticsPreferenceCubit;

  final PrivacyPolicyLauncher? _openPrivacyPolicy;
  final NotificationService? _notificationService;
  final AnalyticsPreferenceCubit? _analyticsPreferenceCubit;

  @override
  Widget build(BuildContext context) {
    final signedIn =
        context.read<AuthBloc>().state.status == AuthStatus.authenticated;
    final content = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.myPageTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        child: Column(
          spacing: 12,
          children: [
            _FrameView(
              title: AppLocalizations.of(context)!.myAccount,
              child: _MyAccountView(),
            ),
            const _FrameView(title: '알람 설정', child: _AlarmStatusView()),
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
                      await deleteUserModal.showDeleteUserModal(
                        context,
                        onConfirm: () {
                          if (context.mounted) {
                            context.go('/signIn');
                          }
                        },
                      );
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
                          await context.push(
                            '/defaultPreparationSpareTimeEdit',
                          );
                      if (updatedPreparation != null) {}
                    },
                  ),
                  _SettingTile(
                    title: AppLocalizations.of(context)!.allowAppNotifications,
                    onTap: () async {
                      await _handleNotificationPermission(
                        context,
                        _notificationService ?? NotificationService.instance,
                      );
                    },
                  ),
                  const _AnalyticsPreferenceTile(),
                  _SettingTile(
                    title: AppLocalizations.of(context)!.privacyPolicy,
                    onTap: () async {
                      await _handlePrivacyPolicyTap(
                        context,
                        _openPrivacyPolicy ?? _openPrivacyPolicyExternally,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (_analyticsPreferenceCubit != null) {
      final analyticsPreferenceCubit = _analyticsPreferenceCubit;
      return BlocProvider<AnalyticsPreferenceCubit>.value(
        value: analyticsPreferenceCubit..load(signedIn: signedIn),
        child: content,
      );
    }
    return BlocProvider<AnalyticsPreferenceCubit>(
      create: (_) =>
          getIt.get<AnalyticsPreferenceCubit>()..load(signedIn: signedIn),
      child: content,
    );
  }
}

class _AnalyticsPreferenceTile extends StatelessWidget {
  const _AnalyticsPreferenceTile();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final signedIn =
        context.read<AuthBloc>().state.status == AuthStatus.authenticated;
    return BlocBuilder<AnalyticsPreferenceCubit, AnalyticsPreferenceState>(
      builder: (context, state) {
        final isUpdating =
            state.status == AnalyticsPreferenceStatus.loading ||
            state.status == AnalyticsPreferenceStatus.updating;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.helpImproveOnTime,
                style: textTheme.bodyLarge,
              ),
            ),
            Switch(
              key: const Key('analyticsPreferenceSwitch'),
              value: state.enabled,
              activeThumbColor: colorScheme.primary,
              onChanged: isUpdating
                  ? null
                  : (value) {
                      context.read<AnalyticsPreferenceCubit>().update(
                        enabled: value,
                        signedIn: signedIn,
                      );
                    },
            ),
          ],
        );
      },
    );
  }
}

Future<bool> _openPrivacyPolicyExternally(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _handlePrivacyPolicyTap(
  BuildContext context,
  PrivacyPolicyLauncher openPrivacyPolicy,
) async {
  var opened = false;
  try {
    opened = await openPrivacyPolicy(ExternalLinks.privacyPolicyUri);
  } catch (_) {
    opened = false;
  }

  if (opened || !context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  await showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: l10n.error,
      description: l10n.privacyPolicyOpenError,
      primaryAction: DialogActionConfig(
        label: l10n.ok,
        variant: ModalWideButtonVariant.primary,
      ),
    ),
  );
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
      final delivery = await _checkAlarmDeliveryPolicy(
        schedulerService: schedulerService,
        fallbackService: fallbackService,
      );

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _alarmsEnabled = settings.alarmsEnabled;
        _statusLabel = _buildStatusLabel(
          l10n: l10n,
          settings: settings,
          records: records,
          delivery: delivery.policy,
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
    required AppLocalizations l10n,
    required AlarmSettings settings,
    required List<ScheduledAlarmRecord> records,
    required AlarmDeliveryPolicy delivery,
  }) {
    if (!settings.alarmsEnabled) return '꺼짐';
    if (records.any((record) => record.provider == AlarmProvider.iosAlarmKit)) {
      return l10n.alarmStatus;
    }
    if (records.any(
      (record) => record.provider == AlarmProvider.androidAlarmManager,
    )) {
      return l10n.preciseNotificationStatus;
    }
    if (records.any(
      (record) => record.provider == AlarmProvider.localNotification,
    )) {
      return l10n.notificationStatus;
    }
    if (!delivery.canDeliver) {
      return l10n.notificationPermissionNeededStatus;
    }
    return l10n.noScheduledNotificationStatus;
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _isUpdating = true;
      _alarmsEnabled = value;
    });
    try {
      final alarmRepository = getIt.get<AlarmRepository>();
      if (value) {
        final schedulerService = getIt.get<AlarmSchedulerService>();
        final fallbackService = getIt.get<FallbackAlarmNotificationService>();

        var delivery = await _checkAlarmDeliveryPolicy(
          schedulerService: schedulerService,
          fallbackService: fallbackService,
        );
        if (!mounted) return;
        if (delivery.policy.blockingPermissionIssue ==
            AlarmPermissionIssue.nativePermissionDenied) {
          final shouldOpenSettings = await _showExactAlarmPermissionDialog(
            context,
          );
          if (!mounted) return;
          if (shouldOpenSettings == DialogActionResult.primary) {
            await schedulerService.requestPermission();
          }
          delivery = await _checkAlarmDeliveryPolicy(
            schedulerService: schedulerService,
            fallbackService: fallbackService,
          );
          if (!delivery.policy.canDeliver &&
              delivery.policy.shouldDisableAlarms) {
            await alarmRepository.updateAlarmSettings(alarmsEnabled: false);
            await getIt.get<CancelAllAlarmsUseCase>()();
            await _load();
            return;
          }
        }

        final fallbackPermission = await fallbackService.requestPermission();
        delivery = _AlarmDeliveryDecision(
          policy: AlarmDeliveryPolicy.evaluate(
            capabilities: delivery.capabilities,
            nativePermission: delivery.nativePermission,
            fallbackPermission: fallbackPermission,
          ),
          capabilities: delivery.capabilities,
          nativePermission: delivery.nativePermission,
          fallbackPermission: fallbackPermission,
        );
        if (!delivery.policy.canDeliver &&
            delivery.policy.shouldDisableAlarms) {
          await alarmRepository.updateAlarmSettings(alarmsEnabled: false);
          await getIt.get<CancelAllAlarmsUseCase>()();
          await _load();
          return;
        }
        await alarmRepository.updateAlarmSettings(alarmsEnabled: true);
        await getIt.get<ReconcileAlarmsUseCase>()();
      } else {
        await alarmRepository.updateAlarmSettings(alarmsEnabled: false);
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
            Text(
              AppLocalizations.of(context)!.scheduleNotificationSetting,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _isLoading ? '확인 중' : _statusLabel,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
        Switch(
          key: const Key('alarmSettingsSwitch'),
          value: _alarmsEnabled,
          onChanged: _isUpdating ? null : _toggle,
        ),
      ],
    );
  }
}

class _AlarmDeliveryDecision {
  const _AlarmDeliveryDecision({
    required this.policy,
    required this.capabilities,
    required this.nativePermission,
    required this.fallbackPermission,
  });

  final AlarmDeliveryPolicy policy;
  final AlarmSchedulerCapabilities capabilities;
  final AlarmPermissionState nativePermission;
  final AlarmPermissionState fallbackPermission;
}

Future<_AlarmDeliveryDecision> _checkAlarmDeliveryPolicy({
  required AlarmSchedulerService schedulerService,
  required FallbackAlarmNotificationService fallbackService,
}) async {
  final capabilities = await schedulerService.getCapabilities();
  final nativePermission = await _checkNativePermission(
    schedulerService,
    capabilities,
  );
  final fallbackPermission = await _checkFallbackPermission(
    fallbackService,
    capabilities,
  );
  return _AlarmDeliveryDecision(
    policy: AlarmDeliveryPolicy.evaluate(
      capabilities: capabilities,
      nativePermission: nativePermission,
      fallbackPermission: fallbackPermission,
    ),
    capabilities: capabilities,
    nativePermission: nativePermission,
    fallbackPermission: fallbackPermission,
  );
}

Future<AlarmPermissionState> _checkNativePermission(
  AlarmSchedulerService schedulerService,
  AlarmSchedulerCapabilities capabilities,
) async {
  if (!capabilities.supportsNativeAlarm ||
      capabilities.nativeAlarmProvider == AlarmProvider.none) {
    return AlarmPermissionState.unsupported;
  }
  return schedulerService.checkPermission();
}

Future<AlarmPermissionState> _checkFallbackPermission(
  FallbackAlarmNotificationService fallbackService,
  AlarmSchedulerCapabilities capabilities,
) async {
  if (capabilities.fallbackProvider != AlarmProvider.localNotification) {
    return AlarmPermissionState.unsupported;
  }
  return fallbackService.checkPermission();
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
          final userName = state.user.nameOrNull;
          final userEmail = state.user.emailOrNull;
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0) +
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
                    Text(userName ?? '', style: textTheme.titleMedium),
                    Text(
                      userEmail ?? '',
                      style: textTheme.bodyMedium!.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
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
  const _FrameView({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 25,
          children: [
            Text(
              title,
              style: textTheme.bodyMedium!.copyWith(color: colorScheme.outline),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.title, required this.onTap});

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
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: colorScheme.outlineVariant,
          ),
        ],
      ),
    );
  }
}

Future<void> _handleNotificationPermission(
  BuildContext context,
  NotificationService notificationService,
) async {
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
        await _showGoToSettingsDialog(context, notificationService);
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
        await _showGoToSettingsDialog(context, notificationService);
      }
    }
  } else {
    await _showGoToSettingsDialog(context, notificationService);
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

Future<DialogActionResult?> _showExactAlarmPermissionDialog(
  BuildContext context,
) async {
  final l10n = AppLocalizations.of(context)!;

  return showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: l10n.exactAlarmPermissionRequired,
      description: l10n.exactAlarmPermissionRequiredDescription,
      secondaryAction: DialogActionConfig(
        label: l10n.doItLater,
        variant: ModalWideButtonVariant.neutral,
      ),
      primaryAction: DialogActionConfig(
        label: l10n.openSettings,
        variant: ModalWideButtonVariant.primary,
      ),
    ),
  );
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

Future<void> _showGoToSettingsDialog(
  BuildContext context,
  NotificationService notificationService,
) async {
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
    await notificationService.openNotificationSettings();
  }
}
