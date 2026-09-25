import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/my_page/cubit/detailed_notification_settings_cubit.dart';
import 'package:on_time_front/domain/entities/schedule_notification_status.dart';
import 'package:on_time_front/presentation/shared/components/notification_timing_education.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_user_use_case.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_delivery_policy.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
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
    return RefreshTheme(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.myPageTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _FrameView(
                title: recurrenceText(context, '알림 설정', 'Notifications'),
                child: Column(
                  children: [
                    const _AlarmStatusView(),
                    const _DetailedNotificationTile(),
                    _AppNotificationTile(
                      service:
                          _notificationService ?? NotificationService.instance,
                    ),
                  ],
                ),
              ),
              _FrameView(
                title: recurrenceText(context, '시간 설정', 'Time settings'),
                child: const _DefaultTimeTiles(),
              ),
              _FrameView(
                title: recurrenceText(context, '일정 관리', 'Schedules'),
                child: _SettingTile(
                  icon: Icons.repeat,
                  title: recurrenceText(
                    context,
                    '반복 일정 관리',
                    'Recurring schedules',
                  ),
                  onTap: () => context.push('/recurringSchedules'),
                ),
              ),
              _FrameView(
                title: recurrenceText(context, '데이터 관리', 'Data'),
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.cloud_upload_outlined,
                      title: recurrenceText(
                        context,
                        '내 데이터 백업',
                        'Back up my data',
                      ),
                      onTap: () => context.push('/myData?action=backup'),
                    ),
                    _SettingTile(
                      icon: Icons.cloud_download_outlined,
                      title: recurrenceText(
                        context,
                        '내 데이터 복원',
                        'Restore my data',
                      ),
                      onTap: () => context.push('/myData?action=restore'),
                    ),
                    _SettingTile(
                      icon: Icons.delete_outline,
                      title: recurrenceText(
                        context,
                        '내 데이터 초기화',
                        'Reset local data',
                      ),
                      onTap: () => context.push('/myData?action=reset'),
                    ),
                  ],
                ),
              ),
              _FrameView(
                title: recurrenceText(context, '기타', 'Other'),
                child: _SettingTile(
                  icon: Icons.privacy_tip_outlined,
                  title: AppLocalizations.of(context)!.privacyPolicy,
                  onTap: () => context.push('/privacyPolicy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultTimeTiles extends StatefulWidget {
  const _DefaultTimeTiles();
  @override
  State<_DefaultTimeTiles> createState() => _DefaultTimeTilesState();
}

class _DefaultTimeTilesState extends State<_DefaultTimeTiles> {
  Future<Duration>? _duration;
  late final Stream<UserEntity>? _user = getIt.isRegistered<StreamUserUseCase>()
      ? getIt<StreamUserUseCase>()()
      : null;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _duration = getIt.isRegistered<GetDefaultPreparationUseCase>()
        ? getIt<GetDefaultPreparationUseCase>()().then((p) => p.totalDuration)
        : null;
  }

  Future<void> _edit() async {
    await context.push('/defaultPreparationSpareTimeEdit');
    if (mounted) setState(_load);
  }

  String? _minutes(Duration? value) => value == null
      ? null
      : recurrenceText(
          context,
          '${value.inMinutes} 분',
          '${value.inMinutes} min',
        );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      FutureBuilder<Duration>(
        future: _duration,
        builder: (context, snapshot) => _SettingTile(
          icon: Icons.timer_outlined,
          title: recurrenceText(context, '기본 준비시간', 'Default preparation'),
          value: _minutes(snapshot.data),
          onTap: _edit,
        ),
      ),
      StreamBuilder<UserEntity>(
        stream: _user,
        builder: (context, snapshot) => _SettingTile(
          icon: Icons.timer_outlined,
          title: recurrenceText(context, '기본 여유시간', 'Default buffer'),
          value: _minutes(snapshot.data?.spareTimeOrNull),
          onTap: _edit,
        ),
      ),
    ],
  );
}

class _AppNotificationTile extends StatefulWidget {
  const _AppNotificationTile({required this.service});
  final NotificationService service;
  @override
  State<_AppNotificationTile> createState() => _AppNotificationTileState();
}

class _AppNotificationTileState extends State<_AppNotificationTile>
    with WidgetsBindingObserver {
  bool? _enabled;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await widget.service.checkNotificationPermission();
      if (mounted) {
        setState(() => _enabled = status == AuthorizationStatus.authorized);
      }
    } catch (_) {
      // The permission row remains usable if the platform status is unavailable.
    }
  }

  Future<void> _request({bool turnOff = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (turnOff) {
        await widget.service.openNotificationSettings();
      } else {
        await _handleNotificationPermission(context, widget.service);
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: _busy ? null : () => _request(),
    child: Row(
      children: [
        const Icon(Icons.phone_iphone, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.allowAppNotifications,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Switch(
          value: _enabled ?? false,
          onChanged: _busy || _enabled == null
              ? null
              : (value) => _request(turnOff: !value),
        ),
      ],
    ),
  );
}

class _DetailedNotificationTile extends StatefulWidget {
  const _DetailedNotificationTile();

  @override
  State<_DetailedNotificationTile> createState() =>
      _DetailedNotificationTileState();
}

class _DetailedNotificationTileState extends State<_DetailedNotificationTile>
    with WidgetsBindingObserver {
  late final _controller = getIt<DetailedNotificationSettingsCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The installation, not this route, owns accepted privacy choices.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<
        DetailedNotificationSettingsCubit,
        DetailedNotificationSettingsState
      >(
        bloc: _controller,
        builder: (context, state) {
          final l10n = AppLocalizations.of(context)!;
          final lines = <String>[];
          if (state.load != DetailedPreferenceLoad.ready) {
            lines.add(switch (state.load) {
              DetailedPreferenceLoad.loading =>
                l10n.detailedNotificationLoading,
              DetailedPreferenceLoad.failed =>
                l10n.detailedNotificationReadFailed,
              DetailedPreferenceLoad.unavailable =>
                l10n.detailedNotificationUnavailable,
              DetailedPreferenceLoad.ready => '',
            });
          }
          if (state.confirmedEnabled != null) {
            lines.add(
              state.confirmedEnabled!
                  ? l10n.detailedNotificationSavedOn
                  : l10n.detailedNotificationSavedOff,
            );
          }
          if (state.requestedEnabled != null) {
            lines.add(
              state.requestedEnabled!
                  ? l10n.detailedNotificationRequestOn
                  : l10n.detailedNotificationRequestOff,
            );
          }
          if (state.save == DetailedPreferenceSave.failed) {
            lines.add(l10n.detailedNotificationSaveFailed);
          }
          final delivery = switch (state.delivery) {
            DetailedPreferenceDelivery.unknown => '',
            DetailedPreferenceDelivery.applying =>
              l10n.detailedNotificationApplying,
            DetailedPreferenceDelivery.delayed =>
              l10n.detailedNotificationDelayed,
            DetailedPreferenceDelivery.applied =>
              l10n.detailedNotificationApplied,
            DetailedPreferenceDelivery.off => l10n.detailedNotificationOff,
            DetailedPreferenceDelivery.noUpcoming =>
              l10n.detailedNotificationEmpty,
            DetailedPreferenceDelivery.permissionNeeded =>
              l10n.detailedNotificationPermission,
            DetailedPreferenceDelivery.cancellationUnconfirmed =>
              l10n.detailedNotificationCancellation,
            DetailedPreferenceDelivery.schedulingFailed =>
              l10n.detailedNotificationSchedulingFailed,
            DetailedPreferenceDelivery.needsCheck =>
              l10n.detailedNotificationNeedsCheck,
            DetailedPreferenceDelivery.contentDeferred =>
              l10n.detailedNotificationHeld,
          };
          if (delivery.isNotEmpty) lines.add(delivery);
          final status = lines.join('\n');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.displayedEnabled == null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline, size: 24),
                  title: Text(l10n.detailedNotificationTitle),
                  subtitle: Text(l10n.detailedNotificationPrivacy),
                )
              else
                SwitchListTile(
                  key: const Key('detailedNotificationSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.detailedNotificationTitle),
                  subtitle: Text(l10n.detailedNotificationPrivacy),
                  secondary: const Icon(Icons.person_outline, size: 24),
                  dense: true,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  value: state.displayedEnabled!,
                  onChanged: state.canRequest ? _controller.request : null,
                ),
              Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  key: const Key('detailedNotificationStatus'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (state.load == DetailedPreferenceLoad.failed ||
                  state.save == DetailedPreferenceSave.failed ||
                  const {
                    DetailedPreferenceDelivery.cancellationUnconfirmed,
                    DetailedPreferenceDelivery.schedulingFailed,
                    DetailedPreferenceDelivery.needsCheck,
                    DetailedPreferenceDelivery.contentDeferred,
                  }.contains(state.delivery))
                TextButton(
                  key: const Key('detailedNotificationRetry'),
                  onPressed: state.canRetry
                      ? () => unawaited(_controller.retry())
                      : null,
                  child: Text(l10n.detailedNotificationRetry),
                ),
            ],
          );
        },
      );
}

class _AlarmStatusView extends StatefulWidget {
  const _AlarmStatusView();

  @override
  State<_AlarmStatusView> createState() => _AlarmStatusViewState();
}

class _AlarmStatusViewState extends State<_AlarmStatusView>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _alarmsEnabled = true;
  String _statusLabel = '확인 중';
  AlarmPermissionState _timingPermission = AlarmPermissionState.unsupported;
  Future<void>? _loading;
  late final _details = getIt<DetailedNotificationSettingsCubit>();
  StreamSubscription<DetailedNotificationSettingsState>? _detailSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detailSubscription = _details.stream.listen((_) {
      if (!mounted) return;
      unawaited(_load(reconcile: false));
    });
    _load();
  }

  @override
  void dispose() {
    _detailSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isUpdating) unawaited(_load());
  }

  Future<void> _load({bool reconcile = true}) =>
      _loading ??= _loadStatus(reconcile).whenComplete(() => _loading = null);

  Future<void> _loadStatus(bool reconcile) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final alarmRepository = getIt.get<AlarmRepository>();
      final registryRepository = getIt.get<AlarmRegistryRepository>();
      final schedulerService = getIt.get<AlarmSchedulerService>();
      final fallbackService = getIt.get<FallbackAlarmNotificationService>();

      if (reconcile) await _details.refresh();
      final settings = await alarmRepository.getAlarmSettings();
      final records = await registryRepository.loadAll();
      final timingPermission = await fallbackService
          .checkExactTimingPermission();
      final delivery = await _checkAlarmDeliveryPolicy(
        schedulerService: schedulerService,
        fallbackService: fallbackService,
      );

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _alarmsEnabled = settings.alarmsEnabled;
        _timingPermission = timingPermission;
        _statusLabel = _buildStatusLabel(
          l10n: l10n,
          settings: settings,
          records: records,
          delivery: delivery.policy,
          result: _details.lastReconciliationResult,
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
    required AlarmReconciliationResult? result,
  }) {
    var status = scheduleNotificationStatus(
      enabled: settings.alarmsEnabled,
      canDeliver: delivery.canDeliver,
      records: records,
      result: result,
      now: DateTime.now(),
      requiresExactTimingEvidence:
          _timingPermission != AlarmPermissionState.unsupported,
    );
    // Current OFF, cleanup and permission evidence remains meaningful even
    // while a content preference is unresolved. Only delivery success claims
    // depend on the latest content request having finished.
    if (status != ScheduleNotificationStatus.off &&
        status != ScheduleNotificationStatus.cleanupNeeded &&
        status != ScheduleNotificationStatus.permissionNeeded &&
        (_details.state.save != DetailedPreferenceSave.idle ||
            const {
              DetailedPreferenceDelivery.unknown,
              DetailedPreferenceDelivery.applying,
              DetailedPreferenceDelivery.delayed,
              DetailedPreferenceDelivery.needsCheck,
              DetailedPreferenceDelivery.contentDeferred,
            }.contains(_details.state.delivery))) {
      status = ScheduleNotificationStatus.incomplete;
    }
    return switch (status) {
      ScheduleNotificationStatus.off => '꺼짐',
      ScheduleNotificationStatus.cleanupNeeded =>
        l10n.notificationCleanupNeededStatus,
      ScheduleNotificationStatus.permissionNeeded =>
        l10n.notificationPermissionNeededStatus,
      ScheduleNotificationStatus.empty => l10n.noScheduledNotificationStatus,
      ScheduleNotificationStatus.alarm => l10n.alarmStatus,
      ScheduleNotificationStatus.notification => l10n.notificationStatus,
      ScheduleNotificationStatus.precise => l10n.preciseNotificationStatus,
      ScheduleNotificationStatus.approximate =>
        l10n.notificationApproximateStatus,
      ScheduleNotificationStatus.mixed => l10n.notificationMixedTimingStatus,
      ScheduleNotificationStatus.incomplete =>
        l10n.notificationIncompleteStatus,
    };
  }

  Future<void> _openTimingSettings() async {
    if (_isUpdating || _isLoading) return;
    setState(() => _isUpdating = true);
    try {
      await getIt<FallbackAlarmNotificationService>()
          .requestExactTimingPermission();
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
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
            requestAlarmReconciliation(getIt<ReconcileAlarmsUseCase>());
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
          requestAlarmReconciliation(getIt<ReconcileAlarmsUseCase>());
          await getIt.get<CancelAllAlarmsUseCase>()();
          await _load();
          return;
        }
        await alarmRepository.updateAlarmSettings(alarmsEnabled: true);
      } else {
        await alarmRepository.updateAlarmSettings(alarmsEnabled: false);
        requestAlarmReconciliation(getIt<ReconcileAlarmsUseCase>());
        await getIt.get<CancelAllAlarmsUseCase>()();
      }
      await _load();
      if (value &&
          mounted &&
          await NotificationTimingEducation.offerOnce(
            context,
            deliveryReconciled: true,
          ) &&
          mounted) {
        await _load();
      }
    } catch (_) {
      // The preference may already be committed. Re-read it and expose the
      // incomplete delivery state instead of undoing it or leaking a Future.
      if (mounted) await _load();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.notifications_none, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.scheduleNotificationSetting,
                    style: textTheme.bodyMedium,
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
            ),
            Switch(
              key: const Key('alarmSettingsSwitch'),
              value: _alarmsEnabled,
              onChanged: _isUpdating || _isLoading ? null : _toggle,
            ),
          ],
        ),
        if (!_isLoading &&
            _timingPermission != AlarmPermissionState.unsupported) ...[
          const SizedBox(height: 8),
          Text(
            _timingPermission == AlarmPermissionState.granted
                ? AppLocalizations.of(context)!.notificationTimingAvailable
                : AppLocalizations.of(context)!.notificationTimingApproximate,
            style: textTheme.bodySmall,
          ),
          TextButton(
            key: const Key('notificationTimingSettings'),
            onPressed: _isUpdating ? null : _openTimingSettings,
            child: Text(
              AppLocalizations.of(context)!.notificationTimingSettings,
            ),
          ),
        ],
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
  const _FrameView({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: textTheme.bodySmall!.copyWith(
                color: colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          RecurrencePanel(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.onTap,
    required this.icon,
    this.value,
  });
  final String title;
  final VoidCallback onTap;
  final IconData icon;
  final String? value;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  value!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
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
