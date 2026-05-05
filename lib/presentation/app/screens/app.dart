import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/navigation_service.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
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
  late final _router =
      goRouterConfig(context.read<AuthBloc>(), context.read<ScheduleBloc>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        getIt.get<AlarmSchedulerService>().initializeLaunchHandling((payload) {
          if (!mounted) return;
          getIt.get<NavigationService>().push('/scheduleStart', extra: payload);
        }),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (context.read<AuthBloc>().state.status != AuthStatus.authenticated) {
      return;
    }
    unawaited(getIt.get<ReconcileAlarmsUseCase>()());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: themeData,
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
