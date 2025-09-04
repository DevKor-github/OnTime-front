import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/app_bloc.dart';

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
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyAccountView extends StatelessWidget {
  const _MyAccountView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        if (state.status == AppStatus.authenticated) {
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
