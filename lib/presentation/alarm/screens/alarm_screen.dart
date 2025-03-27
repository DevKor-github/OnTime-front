import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

import 'package:on_time_front/presentation/alarm/bloc/alarm_screen_preparation_info/alarm_screen_preparation_info_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_bottom_section.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen_top_section.dart';

class AlarmScreen extends StatelessWidget {
  final ScheduleEntity schedule;

  const AlarmScreen({
    super.key,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt.get<AlarmScreenPreparationInfoBloc>()
        ..add(
          AlarmScreenPreparationSubscriptionRequested(
            scheduleId: schedule.id,
            schedule: schedule,
          ),
        ),
      child: BlocBuilder<AlarmScreenPreparationInfoBloc,
          AlarmScreenPreparationInfoState>(
        builder: (context, infoState) {
          if (infoState is AlarmScreenPreparationInfoLoadInProgress ||
              infoState is AlarmScreenPreparationInitial) {
            return const Scaffold(
              backgroundColor: Color(0xff5C79FB),
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (infoState is AlarmScreenPreparationLoadFailure) {
            return Scaffold(
              backgroundColor: const Color(0xff5C79FB),
              body: Center(child: Text(infoState.errorMessage)),
            );
          } else if (infoState is AlarmScreenPreparationLoadSuccess) {
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
              child: _buildAlarmScreen(infoState, context),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAlarmScreen(
    AlarmScreenPreparationLoadSuccess infoState,
    BuildContext context,
  ) {
    return BlocListener<AlarmTimerBloc, AlarmTimerState>(
      listener: (context, timerState) {
        if (timerState is AlarmTimerPreparationCompletion) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(
                '/earlyLate',
                extra: {
                  'earlyLateTime': timerState.beforeOutTime,
                  'isLate': timerState.isLate,
                },
              );
            }
          });
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

            return Column(
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
            );
          },
        ),
      ),
    );
  }
}
