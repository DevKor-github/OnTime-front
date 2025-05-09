import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

import 'package:on_time_front/presentation/alarm/bloc/alarm_screen_preparation_info/alarm_screen_preparation_info_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_bottom_section.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_top_section.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/components/modal_button.dart';

class AlarmScreen extends StatefulWidget {
  final ScheduleEntity schedule;

  const AlarmScreen({super.key, required this.schedule});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _isModalVisible = false;

  void _showModal() => setState(() => _isModalVisible = true);
  void _hideModal() => setState(() => _isModalVisible = false);

  void _navigateToEarlyLate(BuildContext context, AlarmTimerState timerState) {
    context.go(
      '/earlyLate',
      extra: {
        'earlyLateTime': timerState.beforeOutTime,
        'isLate': timerState.isLate,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt.get<AlarmScreenPreparationInfoBloc>()
        ..add(
          AlarmScreenPreparationSubscriptionRequested(
            scheduleId: widget.schedule.id,
            schedule: widget.schedule,
          ),
        ),
      child: BlocBuilder<AlarmScreenPreparationInfoBloc,
          AlarmScreenPreparationInfoState>(
        builder: (context, infoState) {
          if (infoState is AlarmScreenPreparationLoadSuccess) {
            return BlocProvider<AlarmTimerBloc>(
              create: (context) => AlarmTimerBloc(
                preparationSteps: infoState.preparationSteps,
                beforeOutTime: infoState.beforeOutTime,
                isLate: infoState.isLate,
              )..add(
                  AlarmTimerStepStarted(
                    infoState.preparationSteps.first.preparationTime.inSeconds,
                  ),
                ),
              child: _buildAlarmScreen(infoState),
            );
          }
          return const Scaffold(
            backgroundColor: Color(0xff5C79FB),
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  Widget _buildAlarmScreen(AlarmScreenPreparationLoadSuccess infoState) {
    return BlocListener<AlarmTimerBloc, AlarmTimerState>(
      listener: (context, timerState) {
        if (timerState is AlarmTimerPreparationCompletion) {
          // 수동 종료 or 건너뛰기로 준비 완료
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              _navigateToEarlyLate(context, timerState);
            }
          });
        } else if (timerState is AlarmTimerPreparationsTimeOver) {
          // 시간이 다 되어서 종료 → 모달 띄우기
          _showModal();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xff5C79FB),
        body: BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
          builder: (context, timerState) {
            final isLate = timerState.isLate;
            final beforeOutTime = timerState.beforeOutTime;
            final preparationName = timerState
                .preparationSteps[timerState.currentStepIndex].preparationName;
            final preparationRemainingTime =
                timerState.preparationRemainingTime;
            final progress = timerState.progress;

            return Stack(
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
                        preparationSteps: timerState.preparationSteps,
                        currentStepIndex: timerState.currentStepIndex,
                        stepElapsedTimes: timerState.stepElapsedTimes,
                        preparationStepStates: timerState.preparationStepStates,
                        onSkip: () => context
                            .read<AlarmTimerBloc>()
                            .add(const AlarmTimerStepSkipped()),
                        onEndPreparation: () => context
                            .read<AlarmTimerBloc>()
                            .add(const AlarmTimerStepFinalized()),
                      ),
                    ),
                  ],
                ),
                if (_isModalVisible)
                  // 모달 표시
                  TimeoutModalSection(
                      onContinue: _hideModal,
                      onFinish: () =>
                          _navigateToEarlyLate(context, timerState)),
              ],
            );
          },
        ),
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
            color: Colors.black.withOpacity(0.4), // 딤 처리
          ),
        ),
        Center(
          child: CustomAlertDialog(
            title: const Text(
              "준비가 늦어졌나요?",
            ),
            content: const Text(
              "아직 준비가 늦었다면 남아서 계속 준비하세요.\n하지만 늦을 지도 몰라요!",
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              ModalButton(
                onPressed: onContinue,
                text: "계속 준비",
                color: Theme.of(context).colorScheme.primaryContainer,
                textColor: Theme.of(context).colorScheme.primary,
              ),
              ModalButton(
                onPressed: onFinish,
                text: "준비 종료",
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
