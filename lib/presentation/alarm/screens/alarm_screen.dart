import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_bottom_section.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_top_section.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  void _navigateToEarlyLate(
      BuildContext context, int beforeOutTime, bool isLate) {
    context.go(
      '/earlyLate',
      extra: {
        'earlyLateTime': beforeOutTime,
        'isLate': isLate,
      },
    );
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
  Widget build(BuildContext context) {
    return BlocBuilder<ScheduleBloc, ScheduleState>(
      builder: (context, scheduleState) {
        if (scheduleState.status == ScheduleStatus.ongoing ||
            scheduleState.status == ScheduleStatus.started) {
          final schedule = scheduleState.schedule!;
          final preparation = scheduleState.preparation!;

          final now = DateTime.now();
          final spareTime = schedule.scheduleSpareTime ?? Duration.zero;
          final remaining = schedule.scheduleTime.difference(now) -
              schedule.moveTime -
              spareTime;
          final beforeOutTime = remaining.inSeconds;
          final isLate = beforeOutTime < 0;

          final steps =
              List<PreparationStepEntity>.from(preparation.preparationStepList);
          final totalSeconds =
              steps.fold<int>(0, (sum, s) => sum + s.preparationTime.inSeconds);
          final elapsedSeconds = preparation.preparationStepList.fold<int>(
              0,
              (sum, s) =>
                  sum +
                  (s.elapsedTime.inSeconds > s.preparationTime.inSeconds
                      ? s.preparationTime.inSeconds
                      : s.elapsedTime.inSeconds));
          final progress = totalSeconds == 0
              ? 0.0
              : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);

          final currentIndex =
              steps.indexWhere((s) => (s as dynamic).isDone == false);
          final resolvedCurrentIndex =
              currentIndex == -1 ? steps.length - 1 : currentIndex;

          final stepElapsedTimes = preparation.preparationStepList
              .map<int>((s) => s.elapsedTime.inSeconds)
              .toList();

          final preparationStepStates = List<PreparationStateEnum>.generate(
            steps.length,
            (index) {
              if (index < resolvedCurrentIndex)
                return PreparationStateEnum.done;
              if (index == resolvedCurrentIndex && currentIndex != -1) {
                return PreparationStateEnum.now;
              }
              return PreparationStateEnum.yet;
            },
          );

          final currentStep =
              currentIndex == -1 ? steps.last : steps[resolvedCurrentIndex];
          final remainingCurrentSeconds = (currentStep.preparationTime -
                  preparation
                      .preparationStepList[resolvedCurrentIndex].elapsedTime)
              .inSeconds;

          if (currentIndex == -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _navigateToEarlyLate(context, beforeOutTime, isLate);
              }
            });
          }

          return _buildAlarmScreen(
            isLate: isLate,
            beforeOutTime: beforeOutTime,
            preparationName: currentStep.preparationName,
            preparationRemainingTime:
                remainingCurrentSeconds < 0 ? 0 : remainingCurrentSeconds,
            progress: progress.toDouble(),
            preparationSteps: steps,
            currentStepIndex: resolvedCurrentIndex,
            stepElapsedTimes: stepElapsedTimes,
            preparationStepStates: preparationStepStates,
          );
        } else {
          return const Scaffold(
            backgroundColor: Color(0xff5C79FB),
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }

  Widget _buildAlarmScreen({
    required bool isLate,
    required int beforeOutTime,
    required String preparationName,
    required int preparationRemainingTime,
    required double progress,
    required List<PreparationStepEntity> preparationSteps,
    required int currentStepIndex,
    required List<int> stepElapsedTimes,
    required List<PreparationStateEnum> preparationStepStates,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xff5C79FB),
      body: Stack(
        children: [
          Column(
            children: [
              AlarmScreenTopSection(
                isLate: isLate,
                beforeOutTime: beforeOutTime,
                preparationName: preparationName,
                preparationRemainingTime: preparationRemainingTime,
                progress: progress,
              ),
              const SizedBox(height: 110),
              Expanded(
                child: AlarmScreenBottomSection(
                  preparationSteps: preparationSteps,
                  currentStepIndex: currentStepIndex,
                  stepElapsedTimes: stepElapsedTimes,
                  preparationStepStates: preparationStepStates,
                  onSkip: () {},
                  onEndPreparation: () =>
                      _navigateToEarlyLate(context, beforeOutTime, isLate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TimeoutModalSection extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onFinish;

  const TimeoutModalSection({
    super.key,
    required this.onContinue,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          // 배경 딤 처리
          child: Container(
            color: Colors.black.withValues(alpha: 0.4), // 딤 처리
          ),
        ),
        Center(
          child: CustomAlertDialog(
            title: Text(
              AppLocalizations.of(context)!.areYouRunningLate,
            ),
            content: Text(
              AppLocalizations.of(context)!.runningLateDescription,
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              ModalButton(
                onPressed: onContinue,
                text: AppLocalizations.of(context)!.continuePreparing,
                color: Theme.of(context).colorScheme.primaryContainer,
                textColor: Theme.of(context).colorScheme.primary,
              ),
              ModalButton(
                onPressed: onFinish,
                text: AppLocalizations.of(context)!.finishPreparation,
                color: Theme.of(context).colorScheme.primary,
                textColor: Theme.of(context).colorScheme.surface,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
