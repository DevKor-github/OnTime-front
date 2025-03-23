import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_graph_animator.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class AlarmScreenTopSection extends StatelessWidget {
  final bool isLate;
  final int beforeOutTime;

  const AlarmScreenTopSection({
    super.key,
    required this.isLate,
    required this.beforeOutTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BeforeOutTimeText(
          isLate: isLate,
          beforeOutTime: beforeOutTime,
        ),
        const SizedBox(height: 10),
        const _AlarmGraphSection(),
      ],
    );
  }
}

class _BeforeOutTimeText extends StatelessWidget {
  final bool isLate;
  final int beforeOutTime;

  const _BeforeOutTimeText({
    required this.isLate,
    required this.beforeOutTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 45),
      child: Text(
        isLate ? '지각이에요!' : '${formatTime(beforeOutTime)} 뒤에 나가야 해요',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AlarmGraphSection extends StatelessWidget {
  const _AlarmGraphSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
      builder: (context, timerState) {
        final preparationName = timerState
            .preparationSteps[timerState.currentStepIndex].preparationName;
        final preparationRemainingTime = timerState.preparationRemainingTime;

        return SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AlarmGraphAnimator(progress: timerState.progress),
              Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
