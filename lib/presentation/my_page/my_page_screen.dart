import 'package:on_time_front/presentation/recurring/recurrence_labels.dart';
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
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/get_default_preparation_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/stream_user_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({
    super.key,
    NotificationService? notificationService,
    this.referencePreparationMinutes,
    this.referenceSpareMinutes,
  }) : _notificationService = notificationService;

  final NotificationService? _notificationService;
  final int? referencePreparationMinutes;
  final int? referenceSpareMinutes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          children: [
            _FrameView(
              key: const Key('myPageAlarmSection'),
              title: recurrenceText(context, '알림 설정', 'Notifications'),
              child: Column(
                children: [
                  const _AlarmStatusView(),
                  const _DetailedNotificationTile(),
                  _AppNotificationTile(
                    notificationService:
                        _notificationService ?? NotificationService.instance,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _TimeSettingsView(
              referencePreparationMinutes: referencePreparationMinutes,
              referenceSpareMinutes: referenceSpareMinutes,
            ),
            const SizedBox(height: 18),
            _FrameView(
              key: const Key('myPageAppSection'),
              title: recurrenceText(context, '일정 관리', 'Schedules'),
              child: _SettingTile(
                icon: 'my_page_repeat.svg',
                title: recurrenceText(
                  context,
                  '반복 일정 관리',
                  'Recurring schedules',
                ),
                onTap: () => context.push('/recurringSchedules'),
              ),
            ),
            const SizedBox(height: 18),
            _FrameView(
              key: const Key('myPageDataSection'),
              title: recurrenceText(context, '데이터 관리', 'Data'),
              child: Column(
                children: [
                  _SettingTile(
                    icon: 'my_page_upload.svg',
                    title: recurrenceText(
                      context,
                      '내 데이터 백업',
                      'Back up my data',
                    ),
                    divider: true,
                    onTap: () => context.push('/myData?action=backup'),
                  ),
                  _SettingTile(
                    icon: 'my_page_download.svg',
                    title: recurrenceText(
                      context,
                      '내 데이터 복원',
                      'Restore my data',
                    ),
                    divider: true,
                    onTap: () => context.push('/myData?action=restore'),
                  ),
                  _SettingTile(
                    icon: 'my_page_trash.svg',
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
            const SizedBox(height: 18),
            _FrameView(
              title: recurrenceText(context, '기타', 'Other'),
              child: _SettingTile(
                icon: 'my_page_shield.svg',
                title: recurrenceText(
                  context,
                  '개인정보',
                  AppLocalizations.of(context)!.privacyPolicy,
                ),
                onTap: () => context.push('/privacyPolicy'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TimeSettingsView extends StatefulWidget {
  const _TimeSettingsView({
    this.referencePreparationMinutes,
    this.referenceSpareMinutes,
  });

  final int? referencePreparationMinutes;
  final int? referenceSpareMinutes;

  @override
  State<_TimeSettingsView> createState() => _TimeSettingsViewState();
}

class _TimeSettingsViewState extends State<_TimeSettingsView> {
  Future<PreparationEntity>? _preparation;
  Stream<UserEntity>? _user;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<GetDefaultPreparationUseCase>()) {
      _preparation = getIt<GetDefaultPreparationUseCase>()();
    }
    if (getIt.isRegistered<StreamUserUseCase>()) {
      _user = getIt<StreamUserUseCase>()();
    }
  }

  Future<void> _edit() async {
    await context.push('/defaultPreparationSpareTimeEdit');
    if (mounted && getIt.isRegistered<GetDefaultPreparationUseCase>()) {
      setState(() {
        _preparation = getIt<GetDefaultPreparationUseCase>()();
      });
    }
  }

  @override
  Widget build(BuildContext context) => _FrameView(
    title: recurrenceText(context, '시간 설정', 'Time settings'),
    child: Column(
      children: [
        FutureBuilder<PreparationEntity>(
          future: _preparation,
          builder: (context, snapshot) => _SettingTile(
            icon: 'my_page_stopwatch.svg',
            title: recurrenceText(context, '기본 준비시간', 'Default preparation'),
            value: _minuteLabel(
              widget.referencePreparationMinutes ??
                  snapshot.data?.totalDuration.inMinutes,
            ),
            divider: true,
            onTap: _edit,
          ),
        ),
        StreamBuilder<UserEntity>(
          stream: _user,
          builder: (context, snapshot) => _SettingTile(
            icon: 'my_page_stopwatch.svg',
            title: recurrenceText(context, '기본 여유시간', 'Default buffer'),
            value: _minuteLabel(
              widget.referenceSpareMinutes ??
                  snapshot.data?.spareTimeOrNull?.inMinutes,
            ),
            onTap: _edit,
          ),
        ),
      ],
    ),
  );

  String _minuteLabel(int? minutes) => minutes == null
      ? '—'
      : recurrenceText(context, '$minutes 분', '$minutes min');
}

class _AppNotificationTile extends StatefulWidget {
  const _AppNotificationTile({required this.notificationService});

  final NotificationService notificationService;

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
      final status = await widget.notificationService
          .checkNotificationPermission();
      if (mounted) {
        setState(() => _enabled = status == AuthorizationStatus.authorized);
      }
    } catch (_) {
      // Platform permission status can be unavailable while resuming the app.
    }
  }

  Future<void> _request({bool turnOff = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (turnOff) {
        await widget.notificationService.openNotificationSettings();
      } else {
        await _handleNotificationPermission(
          context,
          widget.notificationService,
        );
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SettingTile(
    icon: 'my_page_phone.svg',
    title: AppLocalizations.of(context)!.allowAppNotifications,
    onTap: _busy ? null : () => _request(),
    trailing: _SelectionSwitch(
      value: _enabled ?? false,
      label: AppLocalizations.of(context)!.allowAppNotifications,
      onChanged: _busy || _enabled == null
          ? null
          : (value) => _request(turnOff: !value),
    ),
  );
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
    return _SettingTile(
      icon: 'my_page_person.svg',
      title: recurrenceText(
        context,
        '알림에 일정 이름 표시',
        'Show schedule name in notifications',
      ),
      onTap: _loading ? null : () => _change(!_enabled),
      trailing: _SelectionSwitch(
        key: const Key('detailedNotificationSwitch'),
        value: _enabled,
        label: recurrenceText(
          context,
          '알림에 일정 이름 표시',
          'Show schedule name in notifications',
        ),
        onChanged: _loading ? null : _change,
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
    return Column(
      children: [
        _SettingTile(
          key: const Key('alarmSettingsSwitch'),
          icon: 'my_page_bell.svg',
          title: recurrenceText(
            context,
            '일정 알림 설정',
            AppLocalizations.of(context)!.scheduleNotificationSetting,
          ),
          divider: true,
          onTap: _isUpdating ? null : () => _toggle(!_alarmsEnabled),
        ),
        Semantics(
          value: _isLoading ? '확인 중' : _statusLabel,
          child: _SettingTile(
            icon: 'my_page_clock.svg',
            title: recurrenceText(context, '예정 알림 상태', 'Notification status'),
            value: _isLoading
                ? recurrenceText(context, '확인 중', 'Checking')
                : _alarmsEnabled
                ? recurrenceText(context, '켜짐', 'On')
                : recurrenceText(context, '꺼짐', 'Off'),
            valueIsStatus: true,
            divider: true,
            onTap: _load,
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 25,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xff545454),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: const Color(0xfff6f6f6),
            borderRadius: BorderRadius.circular(7),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.trailing,
    this.divider = false,
    this.valueIsStatus = false,
  });

  final String icon;
  final String title;
  final VoidCallback? onTap;
  final String? value;
  final Widget? trailing;
  final bool divider;
  final bool valueIsStatus;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Stack(
          children: [
            Row(
              children: [
                const SizedBox(width: 14),
                SvgPicture.asset(icon, package: 'assets'),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                  ),
                ),
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: valueIsStatus
                            ? Colors.transparent
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        child: Text(
                          value!,
                          style: TextStyle(
                            fontSize: valueIsStatus ? 12 : 16,
                            color: valueIsStatus
                                ? const Color(0xff4f69df)
                                : const Color(0xff111111),
                          ),
                        ),
                      ),
                    ),
                  ),
                ?trailing,
                if (trailing == null)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: SvgPicture.asset(
                      'my_page_chevron.svg',
                      package: 'assets',
                    ),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
            if (divider)
              const Positioned(
                left: 18,
                right: 18,
                bottom: 0,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xffeeeeee),
                ),
              ),
          ],
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
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: value
              ? SvgPicture.asset('my_page_toggle_on.svg', package: 'assets')
              : Container(
                  width: 40,
                  height: 24,
                  padding: const EdgeInsets.all(2),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0xffd4d8e0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white,
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
