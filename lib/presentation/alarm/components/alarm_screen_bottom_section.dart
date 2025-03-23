import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_list_widget.dart';
import 'package:on_time_front/presentation/shared/components/button.dart';

class AlarmScreenBottomSection extends StatelessWidget {
  const AlarmScreenBottomSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: _PreparationStepListSection()),
        const _EndPreparationButtonSection(),
      ],
    );
  }
}

class _PreparationStepListSection extends StatelessWidget {
  const _PreparationStepListSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
      builder: (context, timerState) {
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
              bottom: 0,
              left: MediaQuery.of(context).size.width * 0.06,
              right: MediaQuery.of(context).size.width * 0.06,
              child: PreparationStepListWidget(
                preparationSteps: timerState.preparationSteps,
                currentStepIndex: timerState.currentStepIndex,
                stepElapsedTimes: timerState.stepElapsedTimes,
                preparationStepStates: timerState.preparationStepStates,
                onSkip: () => context
                    .read<AlarmTimerBloc>()
                    .add(const AlarmTimerStepSkipped()),
              ),
            ),
          ],
        );
      },
    );
  }
}

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
            context.read<AlarmTimerBloc>().add(const AlarmTimerStepFinalized());
          },
        ),
      ),
    );
  }
}
