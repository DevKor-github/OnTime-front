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
import 'package:on_time_front/presentation/shared/router/route_arguments.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, this.nowProvider = DateTime.now});

  final DateTime Function() nowProvider;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  static const _lateContinuePrimary = Color(0xFFBF2E22);
  static const _lateContinuePrimaryContainer = Color(0xFFFFEAE7);
  bool _hasShownCompletionDialog = false;
  bool _isCompletionDialogOpen = false;
  bool _isContinuingAfterCompletion = false;
  bool _navigateAfterFinish = false;
  bool _didNavigateForNotExistsTransition = false;
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

  void _navigateHomeAfterFrame(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      context.go('/home');
    });
  }

  Duration _timeRemainingBeforeLeaving(ScheduleWithPreparationEntity schedule) {
    return schedule.timeRemainingBeforeLeavingAt(widget.nowProvider());
  }

  bool _isLate(ScheduleWithPreparationEntity schedule) {
    return schedule.isLateAt(widget.nowProvider());
  }

  ScheduleWithPreparationEntity? _activeDialogSchedule(String scheduleId) {
    if (!mounted) return null;
    final state = context.read<ScheduleBloc>().state;
    if ((state.status != ScheduleStatus.ongoing &&
            state.status != ScheduleStatus.started) ||
        state.schedule?.id != scheduleId) {
      return null;
    }
    return state.schedule;
  }

  void _requestCompletionDialog(
    BuildContext context,
    ScheduleWithPreparationEntity schedule, {
    bool manual = false,
  }) {
    if (_isCompletionDialogOpen || !mounted) return;
    // Reserve the slot before scheduling the automatic dialog after this frame.
    _isCompletionDialogOpen = true;
    if (!manual) _hasShownCompletionDialog = true;

    if (manual) {
      unawaited(_presentCompletionDialog(context, schedule, manual: true));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_presentCompletionDialog(context, schedule));
      });
    }
  }

  Future<void> _presentCompletionDialog(
    BuildContext context,
    ScheduleWithPreparationEntity schedule, {
    bool manual = false,
  }) async {
    try {
      if (_activeDialogSchedule(schedule.id) == null) return;
      await showPreparationCompletionDialog(
        context: context,
        manual: manual,
        isLate: _isLate(schedule),
        onFinish: () {
          final current = _activeDialogSchedule(schedule.id);
          if (current == null) return;
          final remaining = _timeRemainingBeforeLeaving(current);
          _onPreparationFinished(context, remaining, remaining.isNegative);
        },
        onContinue: () {
          final current = _activeDialogSchedule(schedule.id);
          if (current == null || !current.preparation.isAllStepsDone) return;
          // A manual prompt can outlive the last timer tick. Its Continue choice
          // also acknowledges completion, so do not immediately prompt again.
          _hasShownCompletionDialog = true;
          _isContinuingAfterCompletion = true;
        },
      );
    } finally {
      if (mounted) {
        // Rebuild against the latest timer state after either prompt closes.
        setState(() => _isCompletionDialogOpen = false);
      }
    }
  }

  ThemeData _buildAlarmTheme(BuildContext context, bool isLate) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme.copyWith(
      primary: isLate ? _lateContinuePrimary : AppColors.blue.shade600,
      primaryContainer: isLate
          ? _lateContinuePrimaryContainer
          : AppColors.blue.shade200,
      onPrimaryContainer: isLate
          ? _lateContinuePrimary
          : AppColors.blue.shade900,
    );

    return theme.copyWith(colorScheme: colorScheme);
  }

  void _onPreparationFinished(
    BuildContext context,
    Duration timeRemainingBeforeLeaving,
    bool isLate,
  ) {
    final latenessMinutes = isLate
        ? (timeRemainingBeforeLeaving.inMinutes.abs())
        : 0;
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
        _didNavigateForNotExistsTransition = true;

        if (_navigateAfterFinish &&
            earlyLateSeconds != null &&
            isLate != null) {
          _resetFinishNavigation();
          context.go(
            earlyLateRouteLocation(
              earlyLateTime: earlyLateSeconds,
              isLate: isLate,
            ),
            extra: {'earlyLateTime': earlyLateSeconds, 'isLate': isLate},
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
            _didNavigateForNotExistsTransition = false;

            if (scheduleChanged) {
              _completionScheduleId = schedule.id;
              _resetCompletionUiState();
            }

            if (!preparation.isAllStepsDone && _hasShownCompletionDialog) {
              _resetCompletionUiState();
            }

            if (preparation.isAllStepsDone &&
                !_hasShownCompletionDialog &&
                !_navigateAfterFinish) {
              _requestCompletionDialog(context, schedule);
            }

            _ensureUiTicker(
              preparation.isAllStepsDone && _isContinuingAfterCompletion,
            );
            return _buildAlarmScreen(schedule: schedule);
          } else if (scheduleState.status == ScheduleStatus.upcoming &&
              scheduleState.schedule != null) {
            _completionScheduleId = scheduleState.schedule!.id;
            _didNavigateForNotExistsTransition = false;
            _resetCompletionUiState();
            _ensureUiTicker(true);
            return _buildEarlyStartReadyScreen(scheduleState.schedule!);
          } else if (scheduleState.status == ScheduleStatus.notExists) {
            _completionScheduleId = null;
            _resetCompletionUiState();
            _ensureUiTicker(false);
            if (!_navigateAfterFinish && !_didNavigateForNotExistsTransition) {
              _navigateHomeAfterFrame(context);
            }
            return const Scaffold(
              backgroundColor: Color(0xff5C79FB),
              body: Center(child: CircularProgressIndicator()),
            );
          } else {
            _completionScheduleId = null;
            _didNavigateForNotExistsTransition = false;
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

  Widget _buildAlarmScreen({required ScheduleWithPreparationEntity schedule}) {
    final timeRemainingBeforeLeaving = _timeRemainingBeforeLeaving(schedule);
    final isLate = timeRemainingBeforeLeaving.isNegative;
    final preparation = schedule.preparation;
    final l10n = AppLocalizations.of(context)!;
    final isContinuingAfterCompletion =
        preparation.isAllStepsDone && _isContinuingAfterCompletion;
    final isLateContinueMode = isContinuingAfterCompletion && isLate;
    final isReadyContinueMode = isContinuingAfterCompletion && !isLate;
    final timerLabel = isLateContinueMode
        ? '지각이에요'
        : isReadyContinueMode
        ? l10n.preparationReadyToGo
        : preparation.currentStepName;
    final displayProgress = isLateContinueMode ? 0.0 : preparation.progress;
    final displayRemainingSeconds = isContinuingAfterCompletion
        ? timeRemainingBeforeLeaving.inSeconds.abs()
        : preparation.currentStepRemainingTime.inSeconds;

    if (!isContinuingAfterCompletion) {
      _ensureUiTicker(false);
    }

    final alarmTheme = _buildAlarmTheme(context, isLate);

    return Theme(
      key: const ValueKey('alarm_screen_theme'),
      data: alarmTheme,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: isLate ? AppColors.red.shade50 : AppColors.blue,
            body: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Column(
                    children: [
                      SizedBox(
                        height: (constraints.maxHeight * 426 / 844).clamp(
                          220.0,
                          426.0,
                        ),
                        child: AlarmScreenTopSection(
                          isLate: isLate,
                          beforeOutTime: timeRemainingBeforeLeaving.inSeconds,
                          preparationName: timerLabel,
                          showPreparationName: true,
                          preparationRemainingTime: displayRemainingSeconds,
                          progress: displayProgress,
                        ),
                      ),
                      Expanded(
                        child: AlarmScreenBottomSection(
                          preparation: preparation,
                          onSkip: () {
                            context.read<ScheduleBloc>().add(
                              const ScheduleStepSkipped(),
                            );
                          },
                          onEndPreparation: () => _requestCompletionDialog(
                            context,
                            schedule,
                            manual: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      minimum: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          key: const Key('alarm_close_button'),
                          tooltip: AppLocalizations.of(context)!.home,
                          icon: Icon(
                            Icons.close,
                            color: isLate
                                ? AppColors.red.shade900
                                : AppColors.white,
                          ),
                          onPressed: () => context.go('/home'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEarlyStartReadyScreen(ScheduleWithPreparationEntity schedule) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final remaining = schedule.preparationStartTime
        .difference(widget.nowProvider())
        .inSeconds;
    final clampedRemaining = remaining.isNegative ? 0 : remaining;

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primaryContainer,
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
                    context.read<ScheduleBloc>().add(
                      const SchedulePreparationStarted(),
                    );
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
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
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
