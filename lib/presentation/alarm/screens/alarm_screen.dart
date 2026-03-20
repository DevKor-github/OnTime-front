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
  const AlarmScreen({
    super.key,
    this.nowProvider = DateTime.now,
  });

  final DateTime Function() nowProvider;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _hasShownCompletionDialog = false;
  bool _isContinuingAfterCompletion = false;
  bool _navigateAfterFinish = false;
  int? _pendingEarlyLateSeconds;
  bool? _pendingIsLate;
  Timer? _uiTickerTimer;
  String? _completionScheduleId;

  void _resetFinishNavigation() {
    _navigateAfterFinish = false;
    _pendingEarlyLateSeconds = null;
    _pendingIsLate = null;
  }

  void _resetCompletionUiState() {
    _hasShownCompletionDialog = false;
    _isContinuingAfterCompletion = false;
  }

  Duration _timeRemainingBeforeLeaving(ScheduleWithPreparationEntity schedule) {
    return schedule.timeRemainingBeforeLeavingAt(widget.nowProvider());
  }

  bool _isLate(ScheduleWithPreparationEntity schedule) {
    return schedule.isLateAt(widget.nowProvider());
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

  void _ensureUiTicker(bool active) {
    if (!active) {
      _uiTickerTimer?.cancel();
      _uiTickerTimer = null;
      return;
    }
    if (_uiTickerTimer != null) return;
    _uiTickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    _uiTickerTimer?.cancel();
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
            final scheduleChanged = _completionScheduleId != schedule.id;

            if (scheduleChanged) {
              _completionScheduleId = schedule.id;
              _resetCompletionUiState();
            }

            if (!preparation.isAllStepsDone && _hasShownCompletionDialog) {
              _resetCompletionUiState();
            }

            if (preparation.isAllStepsDone && !_hasShownCompletionDialog) {
              _hasShownCompletionDialog = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                showPreparationCompletionDialog(
                  context: context,
                  isLate: _isLate(schedule),
                  onFinish: () {
                    final timeRemainingBeforeLeaving =
                        _timeRemainingBeforeLeaving(schedule);
                    _onPreparationFinished(
                      context,
                      timeRemainingBeforeLeaving,
                      timeRemainingBeforeLeaving.isNegative,
                    );
                  },
                  onContinue: () {
                    if (!mounted) return;
                    setState(() {
                      _isContinuingAfterCompletion = true;
                    });
                  },
                );
              });
            }

            _ensureUiTicker(preparation.isAllStepsDone &&
                _isContinuingAfterCompletion);
            return _buildAlarmScreen(
              schedule: schedule,
            );
          } else if (scheduleState.status == ScheduleStatus.upcoming &&
              scheduleState.schedule != null) {
            _completionScheduleId = scheduleState.schedule!.id;
            _resetCompletionUiState();
            _ensureUiTicker(true);
            return _buildEarlyStartReadyScreen(scheduleState.schedule!);
          } else {
            _completionScheduleId = null;
            _resetCompletionUiState();
            _ensureUiTicker(false);
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
    final timeRemainingBeforeLeaving = _timeRemainingBeforeLeaving(schedule);
    final isLate = timeRemainingBeforeLeaving.isNegative;
    final preparation = schedule.preparation;
    final displayRemainingSeconds = preparation.isAllStepsDone &&
            _isContinuingAfterCompletion
        ? timeRemainingBeforeLeaving.inSeconds.abs()
        : preparation.currentStepRemainingTime.inSeconds;

    if (!(preparation.isAllStepsDone && _isContinuingAfterCompletion)) {
      _ensureUiTicker(false);
    }

    return Scaffold(
      backgroundColor: const Color(0xff5C79FB),
      body: Stack(
        children: [
          Column(
            children: [
              AlarmScreenTopSection(
                isLate: isLate,
                beforeOutTime: timeRemainingBeforeLeaving.inSeconds,
                preparationName: preparation.currentStepName,
                preparationRemainingTime: displayRemainingSeconds,
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
                  onEndPreparation: () => _onPreparationFinished(
                    context,
                    timeRemainingBeforeLeaving,
                    isLate,
                  ),
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
        schedule.preparationStartTime.difference(widget.nowProvider()).inSeconds;
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
