import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_bottom_section.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_top_section.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_completion_dialog.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _hasShownCompletionDialog = false;
  bool _navigateAfterFinish = false;
  int? _pendingEarlyLateSeconds;
  bool? _pendingIsLate;
  Timer? _upcomingCountdownTimer;

  void _resetFinishNavigation() {
    _navigateAfterFinish = false;
    _pendingEarlyLateSeconds = null;
    _pendingIsLate = null;
  }

  void _onPreparationFinished(
      BuildContext context, Duration timeRemainingBeforeLeaving, bool isLate) {
    final latenessMinutes =
        isLate ? (timeRemainingBeforeLeaving.inMinutes.abs()) : 0;
    _pendingEarlyLateSeconds = timeRemainingBeforeLeaving.inSeconds;
    _pendingIsLate = isLate;
    _navigateAfterFinish = true;
    context.read<ScheduleBloc>().add(ScheduleFinished(latenessMinutes));
  }

  void _ensureUpcomingTicker(bool active) {
    if (!active) {
      _upcomingCountdownTimer?.cancel();
      _upcomingCountdownTimer = null;
      return;
    }
    if (_upcomingCountdownTimer != null) return;
    _upcomingCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ScheduleBloc>().add(const ScheduleSubscriptionRequested());
      }
    });
  }

  @override
  void dispose() {
    _upcomingCountdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScheduleBloc, ScheduleState>(
      listenWhen: (previous, current) {
        return previous.status != ScheduleStatus.notExists &&
            current.status == ScheduleStatus.notExists;
      },
      listener: (context, scheduleState) {
        final earlyLateSeconds = _pendingEarlyLateSeconds;
        final isLate = _pendingIsLate;

        if (_navigateAfterFinish &&
            earlyLateSeconds != null &&
            isLate != null) {
          _resetFinishNavigation();
          context.go(
            '/earlyLate',
            extra: {
              'earlyLateTime': earlyLateSeconds,
              'isLate': isLate,
            },
          );
          return;
        }

        _resetFinishNavigation();
        context.go('/home');
      },
      child: BlocBuilder<ScheduleBloc, ScheduleState>(
        builder: (context, scheduleState) {
          if (scheduleState.status == ScheduleStatus.ongoing ||
              scheduleState.status == ScheduleStatus.started) {
            final schedule = scheduleState.schedule!;
            final preparation = schedule.preparation;

            if (preparation.isAllStepsDone && !_hasShownCompletionDialog) {
              _hasShownCompletionDialog = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                showPreparationCompletionDialog(
                  context: context,
                  isLate: schedule.isLate,
                  onFinish: () {
                    _onPreparationFinished(
                      context,
                      schedule.timeRemainingBeforeLeaving,
                      schedule.isLate,
                    );
                  },
                );
              });
            }

            return _buildAlarmScreen(
              schedule: schedule,
            );
          } else if (scheduleState.status == ScheduleStatus.upcoming &&
              scheduleState.schedule != null) {
            _ensureUpcomingTicker(true);
            return _buildEarlyStartReadyScreen(scheduleState.schedule!);
          } else {
            _ensureUpcomingTicker(false);
            return const Scaffold(
              backgroundColor: Color(0xff5C79FB),
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }

  Widget _buildAlarmScreen({
    required ScheduleWithPreparationEntity schedule,
  }) {
    _ensureUpcomingTicker(false);
    final preparation = schedule.preparation;
    return Scaffold(
      backgroundColor: const Color(0xff5C79FB),
      body: Stack(
        children: [
          Column(
            children: [
              AlarmScreenTopSection(
                isLate: schedule.isLate,
                beforeOutTime: schedule.timeRemainingBeforeLeaving.inSeconds,
                preparationName: preparation.currentStepName,
                preparationRemainingTime:
                    preparation.currentStepRemainingTime.inSeconds,
                progress: preparation.progress,
              ),
              const SizedBox(height: 110),
              Expanded(
                child: AlarmScreenBottomSection(
                  preparation: preparation,
                  onSkip: () {
                    context
                        .read<ScheduleBloc>()
                        .add(const ScheduleStepSkipped());
                  },
                  onEndPreparation: () => _onPreparationFinished(context,
                      schedule.timeRemainingBeforeLeaving, schedule.isLate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarlyStartReadyScreen(ScheduleWithPreparationEntity schedule) {
    final l10n = AppLocalizations.of(context)!;
    final remaining =
        schedule.preparationStartTime.difference(DateTime.now()).inSeconds;
    final clampedRemaining = remaining.isNegative ? 0 : remaining;

    return Scaffold(
      backgroundColor: const Color(0xff5C79FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                schedule.scheduleName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.preparationStartsInFiveMinutes,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xffDCE3FF),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                formatTimeTimer(clampedRemaining),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 57,
                child: ElevatedButton(
                  onPressed: () {
                    context
                        .read<ScheduleBloc>()
                        .add(const SchedulePreparationStarted());
                  },
                  child: Text(l10n.startPreparing),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 57,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Text(l10n.home),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
