import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';

import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_screen_preparation_info/alarm_screen_preparation_info_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen/alarm_graph_animator.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen/preparation_step_list_widget.dart';

import 'package:on_time_front/presentation/shared/components/button.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class AlarmScreen extends StatelessWidget {
  final ScheduleEntity schedule;

  const AlarmScreen({
    super.key,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AlarmScreenPreparationInfoBloc>(
      create: (context) => AlarmScreenPreparationInfoBloc(
        getPreparationByScheduleIdUseCase:
            context.read<GetPreparationByScheduleIdUseCase>(),
      )..add(
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
          GoRouter.of(context).go('/earlyLate', extra: schedule);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xff5C79FB),
        body: Column(
          children: [
            _GoOutTimeText(infoState: infoState),
            const SizedBox(height: 10),
            _AlarmGraphSection(infoState: infoState),
            const SizedBox(height: 110),
            Expanded(
              child: _PreparationStepListSection(infoState: infoState),
            ),
            const _EndPreparationButtonSection(),
          ],
        ),
      ),
    );
  }
}

/// 상단 상태 표시 컴포넌트
class _GoOutTimeText extends StatelessWidget {
  final AlarmScreenPreparationLoadSuccess infoState;

  const _GoOutTimeText({super.key, required this.infoState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 45),
      child: BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
        builder: (context, timerState) {
          return Text(
            infoState.isLate
                ? '지각이에요!'
                : '${formatTime(infoState.beforeOutTime)} 뒤에 나가야 해요',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}

/// 그래프 및 상태 표시 컴포넌트
class _AlarmGraphSection extends StatelessWidget {
  final AlarmScreenPreparationLoadSuccess infoState;

  const _AlarmGraphSection({super.key, required this.infoState});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AlarmGraphAnimator(),
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
              builder: (context, timerState) {
                final preparationName = infoState
                    .preparationSteps[timerState.currentStepIndex]
                    .preparationName;
                final preparationRemainingTime =
                    timerState.preparationRemainingTime;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      preparationName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffDCE3FF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatTimeTimer(preparationRemainingTime),
                      style: const TextStyle(
                        fontSize: 35,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 준비 단계 목록 컴포넌트
class _PreparationStepListSection extends StatelessWidget {
  final AlarmScreenPreparationLoadSuccess infoState;

  const _PreparationStepListSection({super.key, required this.infoState});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xffF6F6F6),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
          ),
        ),
        Positioned(
          top: 15,
          bottom: 80,
          left: MediaQuery.of(context).size.width * 0.06,
          right: MediaQuery.of(context).size.width * 0.06,
          child: PreparationStepListWidget(
            preparations: infoState.preparationSteps,
            onSkip: () {
              context.read<AlarmTimerBloc>().add(
                    const AlarmTimerStepSkipped(),
                  );
            },
          ),
        ),
      ],
    );
  }
}

/// 준비 종료 버튼 컴포넌트
class _EndPreparationButtonSection extends StatelessWidget {
  const _EndPreparationButtonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Button(
          text: '준비 종료',
          onPressed: () {
            context.read<AlarmTimerBloc>().add(
                  const AlarmTimerStepFinalized(),
                );
          },
        ),
      ),
    );
  }
}
