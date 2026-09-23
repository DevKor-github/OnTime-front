import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/detailed_notification_preference_service.dart';
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
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key, NotificationService? notificationService})
    : _notificationService = notificationService;

  final NotificationService? _notificationService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            AppLocalizations.of(context)!.myPageTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        toolbarHeight: 47,
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        child: Column(
          spacing: 12,
          children: [
            const _FrameView(
              key: Key('myPageAlarmSection'),
              title: '알람 설정',
              child: _AlarmStatusView(),
            ),
            _FrameView(
              key: const Key('myPageDataSection'),
              title: '내 데이터',
              child: _SettingTile(
                title: '백업, 복원 및 로컬 데이터 초기화',
                onTap: () => context.push('/myData'),
              ),
            ),
            _FrameView(
              key: const Key('myPageAppSection'),
              title: AppLocalizations.of(context)!.appSettings,
              child: Column(
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
                  const _DetailedNotificationTile(),
                  _SettingTile(
                    title: AppLocalizations.of(context)!.allowAppNotifications,
                    minHeight: 68,
                    onTap: () async {
                      await _handleNotificationPermission(
                        context,
                        _notificationService ?? NotificationService.instance,
                      );
                    },
                  ),
                  _SettingTile(
                    title: AppLocalizations.of(context)!.privacyPolicy,
                    onTap: () => context.push('/privacyPolicy'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailedNotificationTile extends StatefulWidget {
  const _DetailedNotificationTile();

  @override
  State<_DetailedNotificationTile> createState() =>
      _DetailedNotificationTileState();
}

class _DetailedNotificationTileState extends State<_DetailedNotificationTile> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await getIt<DetailedNotificationPreferenceService>()
        .getEnabled();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _change(bool enabled) async {
    setState(() => _enabled = enabled);
    await getIt<DetailedNotificationPreferenceService>().setEnabled(enabled);
    await getIt<ReconcileAlarmsUseCase>()();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: _loading ? null : () => _change(!_enabled),
      child: Semantics(
        button: true,
        toggled: _enabled,
        label: '알림에 일정 이름 표시',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 76,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('알림에 일정 이름 표시', style: textTheme.bodyLarge),
                      const SizedBox(height: 4),
                      Text(
                        '기본값은 잠금 화면에 상세 내용을 표시하지 않습니다.',
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: _SelectionSwitch(
                    key: const Key('detailedNotificationSwitch'),
                    value: _enabled,
                    label: '알림에 일정 이름 표시',
                    onChanged: null,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
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
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
            _SelectionSwitch(
              key: const Key('alarmSettingsSwitch'),
              value: _alarmsEnabled,
              label: AppLocalizations.of(context)!.scheduleNotificationSetting,
              onChanged: _isUpdating ? null : _toggle,
            ),
          ],
        ),
      ),
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
  if (!_shouldRecoverNativeAlarmPermission(capabilities)) {
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

bool _shouldRecoverNativeAlarmPermission(
  AlarmSchedulerCapabilities capabilities,
) {
  return capabilities.supportsNativeAlarm &&
      capabilities.nativeAlarmProvider != AlarmProvider.none &&
      nativeAlarmProviderAllowedByReleasePolicy(
        capabilities.nativeAlarmProvider,
      );
}

class _FrameView extends StatelessWidget {
  const _FrameView({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Center(
                child: Text(
                  title,
                  style: textTheme.bodyMedium!.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.onTap,
    this.minHeight = 64,
  });

  final String title;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(title, style: textTheme.bodyLarge),
              ),
              RotatedBox(
                quarterTurns: 2,
                child: SvgPicture.asset(
                  'chevron_left.svg',
                  package: 'assets',
                  width: 8,
                  height: 14,
                  colorFilter: ColorFilter.mode(
                    colorScheme.outlineVariant,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionSwitch extends StatelessWidget {
  const _SelectionSwitch({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: value,
    enabled: onChanged != null,
    label: label,
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF4F69DF)
                    : const Color(0xFFE8E8E8),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
