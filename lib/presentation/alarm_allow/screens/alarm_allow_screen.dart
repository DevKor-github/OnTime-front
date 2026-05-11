import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/cubit/alarm_gate_cubit.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

class AlarmAllowScreen extends StatefulWidget {
  const AlarmAllowScreen({super.key});

  @override
  State<AlarmAllowScreen> createState() => _AlarmAllowScreenState();
}

class _AlarmAllowScreenState extends State<AlarmAllowScreen>
    with WidgetsBindingObserver {
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<AlarmGateCubit>().refreshPermission(
      disableAlarmsWhenPermissionMissing: true,
      enableAlarmsOnGrant: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isRequesting = true;
    });
    final permission = await context.read<AlarmGateCubit>().requestPermission();
    if (!mounted) return;
    setState(() {
      _isRequesting = false;
    });
    if (permission == AlarmPermissionState.granted ||
        permission == AlarmPermissionState.unsupported) {
      context.go('/home');
    }
  }

  Future<void> _dismiss() async {
    await context.read<AlarmGateCubit>().dismissPrompt();
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
                  children: const [_Image(), _Title()],
                ),
              ),
            ),
            _Buttons(
              isRequesting: _isRequesting,
              onAllow: _requestPermission,
              onDismiss: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.isRequesting,
    required this.onAllow,
    required this.onDismiss,
  });

  final bool isRequesting;
  final Future<void> Function() onAllow;
  final Future<void> Function() onDismiss;

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
          onPressed: isRequesting ? null : () => onAllow(),
          child: Text(
            AppLocalizations.of(context)!.allowAlarms,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: isRequesting ? null : () => onDismiss(),
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
          AppLocalizations.of(context)!.pleaseAllowAlarms,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
        ),
        SizedBox(
          width: 282,
          child: Text(
            AppLocalizations.of(context)!.alarmPermissionDescription,
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
