import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/use-cases/get_preparation_by_schedule_id_use_case.dart';

import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_screen_preparation_info/alarm_screen_preparation_info_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen/alarm_graph_component.dart';
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
                body: Center(child: CircularProgressIndicator()));
          } else if (infoState is AlarmScreenPreparationLoadFailure) {
            return Scaffold(
                backgroundColor: const Color(0xff5C79FB),
                body: Center(child: Text(infoState.errorMessage)));
          } else if (infoState is AlarmScreenPreparationLoadSuccess) {
            return BlocProvider<AlarmTimerBloc>(
              create: (context) =>
                  AlarmTimerBloc(preparationSteps: infoState.preparationSteps)
                    ..add(TimerStepStarted(infoState
                        .preparationSteps.first.preparationTime.inSeconds)),
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
            Padding(
              padding: const EdgeInsets.only(top: 52),
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
            ),
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(230, 115),
                    painter: AlarmGraphComponent(
                      progress: infoState.progress,
                      preparationRatios: infoState.preparationRatios,
                      preparationCompleted: infoState.preparationCompleted,
                    ),
                  ),
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
            ),
            const SizedBox(height: 110),
            Expanded(
              child: Stack(
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
                    bottom: 100,
                    left: MediaQuery.of(context).size.width * 0.06,
                    right: MediaQuery.of(context).size.width * 0.06,
                    child: PreparationStepListWidget(
                      preparations: infoState.preparationSteps,
                      onSkip: () {
                        context.read<AlarmTimerBloc>().add(
                              const TimerStepSkipped(),
                            );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Builder(
                        builder: (context) {
                          return Button(
                            text: '준비 종료',
                            onPressed: () {
                              context
                                  .read<AlarmTimerBloc>()
                                  .add(const TimerStepFinalized());
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
