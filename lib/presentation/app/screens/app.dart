import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/app_bloc.dart';
import 'package:on_time_front/presentation/shared/router/go_router.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class App extends StatelessWidget {
  App({super.key});
  final bloc = getIt.get<AppBloc>()..add(const AppUserSubscriptionRequested());

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppBloc>(
      create: (context) => bloc,
      child: MaterialApp.router(
        routerConfig: goRouterConfig(bloc),
        theme: themeData,
      ),
    );
  }
}
