import 'package:on_time_front/presentation/shared/components/notification_timing_education.dart';
import 'package:on_time_front/core/services/notification_service.dart';
import 'package:on_time_front/core/services/notification_tap_router.dart';
import 'package:on_time_front/domain/use-cases/schedule_preparation_session_use_case.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/app/cubit/alarm_gate_cubit.dart';
import 'package:on_time_front/presentation/app/cubit/notification_gate_cubit.dart';
import 'package:on_time_front/presentation/shared/router/go_router.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) =>
              getIt.get<AuthBloc>()..add(const AuthUserSubscriptionRequested()),
        ),
        BlocProvider<ScheduleBloc>(
          create: (context) => getIt.get<ScheduleBloc>(),
        ),
        BlocProvider<NotificationGateCubit>(
          create: (context) => NotificationGateCubit(),
        ),
        BlocProvider<AlarmGateCubit>(create: (context) => AlarmGateCubit()),
      ],
      child: const AppView(),
    );
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppRouterView();
  }
}

class _AppRouterView extends StatefulWidget {
  const _AppRouterView();

  @override
  State<_AppRouterView> createState() => _AppRouterViewState();
}

class _AppRouterViewState extends State<_AppRouterView>
    with WidgetsBindingObserver {
  static const _logTag = '[AppAlarmLaunch]';

  late final _router = goRouterConfig(
    context.read<AuthBloc>(),
    context.read<NotificationGateCubit>(),
    context.read<AlarmGateCubit>(),
  );
  final _alarmLaunchPollTimers = <Timer>[];
  NavigationNotificationTapRouter? get _tapRouter {
    final router = getIt.get<NotificationTapRouter>();
    return router is NavigationNotificationTapRouter ? router : null;
  }

  bool _readyForNotification() =>
      mounted &&
      appRedirectLocation(
            authStatus: context.read<AuthBloc>().state.status,
            notificationGateState: context.read<NotificationGateCubit>().state,
            alarmGateState: context.read<AlarmGateCubit>().state,
            path: '/scheduleStart',
          ) ==
          null &&
      _router.routerDelegate.navigatorKey.currentContext != null;

  void _offerTimingEducation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_readyForNotification() ||
          _router.routeInformationProvider.value.uri.path != '/home') {
        return;
      }
      final navigatorContext =
          _router.routerDelegate.navigatorKey.currentContext;
      if (navigatorContext != null) {
        unawaited(
          NotificationTimingEducation.offerOnce(
            navigatorContext,
            isCurrent: () =>
                mounted &&
                _readyForNotification() &&
                _router.routeInformationProvider.value.uri.path == '/home',
          ),
        );
      }
    });
  }

  void _retryNotificationTap() {
    if (!mounted) return;
    _tapRouter?.retry();
    _offerTimingEducation();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tapRouter?.configure(
        isReady: _readyForNotification,
        resolve: (id, current) => getIt
            .get<SchedulePreparationSessionUseCase>()
            .resolvePromptedSchedule(
              scheduleId: id,
              startPreparation: false,
              isCurrent: current,
            ),
      );
      _router.routerDelegate.addListener(_retryNotificationTap);
      unawaited(NotificationService.instance.collectInitialLaunch());
      AppLogger.debug('$_logTag initialize launch handling');
      unawaited(
        getIt.get<AlarmSchedulerService>().initializeLaunchHandling(
          _handleAlarmLaunchPayload,
        ),
      );
      _schedulePendingAlarmLaunchPolls();
      if (context.read<AuthBloc>().state.status == AuthStatus.authenticated) {
        unawaited(
          context.read<AlarmGateCubit>().refreshPermission(
            disableAlarmsWhenPermissionMissing: true,
          ),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.debug('$_logTag lifecycle state=$state');
    context.read<ScheduleBloc>().observeLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    unawaited(HardwareKeyboard.instance.syncKeyboardState().catchError((_) {}));
    context.read<ScheduleBloc>().add(
      const SchedulePreparationTimeRefreshRequested(
        origin: PreparationRefreshOrigin.resume,
      ),
    );
    unawaited(
      getIt.get<AlarmSchedulerService>().dispatchPendingLaunchPayload(),
    );
    _schedulePendingAlarmLaunchPolls();
    unawaited(NotificationService.instance.collectInitialLaunch());
    _retryNotificationTap();
    if (context.read<AuthBloc>().state.status != AuthStatus.authenticated) {
      return;
    }
    unawaited(
      context.read<AlarmGateCubit>().refreshPermission(
        disableAlarmsWhenPermissionMissing: true,
      ),
    );
    requestAlarmReconciliation(getIt.get<ReconcileAlarmsUseCase>());
  }

  void _handleAlarmLaunchPayload(Map<String, String> payload) {
    if (!mounted) return;
    _tapRouter?.routeNativeNotificationTap(payload);
  }

  void _schedulePendingAlarmLaunchPolls() {
    AppLogger.debug('$_logTag scheduling pending launch payload polls');
    for (final timer in _alarmLaunchPollTimers) {
      timer.cancel();
    }
    _alarmLaunchPollTimers.clear();
    const delays = [
      Duration(milliseconds: 300),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];
    final alarmSchedulerService = getIt.get<AlarmSchedulerService>();
    for (final delay in delays) {
      _alarmLaunchPollTimers.add(
        Timer(delay, () {
          if (!mounted) return;
          AppLogger.debug('$_logTag poll getLaunchPayload delay=$delay');
          unawaited(alarmSchedulerService.dispatchPendingLaunchPayload());
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in _alarmLaunchPollTimers) {
      timer.cancel();
    }
    _router.routerDelegate.removeListener(_retryNotificationTap);
    _tapRouter?.detach();
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NotificationGateCubit, NotificationGateState>(
          listener: (_, _) => _retryNotificationTap(),
        ),
        BlocListener<AlarmGateCubit, AlarmGateState>(
          listener: (_, _) => _retryNotificationTap(),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            _retryNotificationTap();
            if (state.status == AuthStatus.authenticated) {
              unawaited(
                context.read<AlarmGateCubit>().refreshPermission(
                  disableAlarmsWhenPermissionMissing: true,
                ),
              );
            }
          },
        ),
      ],
      child: MaterialApp.router(
        theme: themeData,
        routerConfig: _router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
