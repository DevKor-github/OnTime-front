import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_list_widget.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class AlarmScreenBottomSection extends StatelessWidget {
  final List<PreparationStepEntity> preparationSteps;
  final int currentStepIndex;
  final List<int> stepElapsedTimes;
  final List<PreparationStateEnum> preparationStepStates;
  final VoidCallback onSkip;
  final VoidCallback onEndPreparation;

  const AlarmScreenBottomSection({
    super.key,
    required this.preparationSteps,
    required this.currentStepIndex,
    required this.stepElapsedTimes,
    required this.preparationStepStates,
    required this.onSkip,
    required this.onEndPreparation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
            child: _PreparationStepListSection(
          preparationSteps: preparationSteps,
          currentStepIndex: currentStepIndex,
          stepElapsedTimes: stepElapsedTimes,
          preparationStepStates: preparationStepStates,
          onSkip: onSkip,
        )),
        _EndPreparationButtonSection(
          onEndPreparation: onEndPreparation,
        ),
      ],
    );
  }
}

class _PreparationStepListSection extends StatelessWidget {
  final List<PreparationStepEntity> preparationSteps;
  final int currentStepIndex;
  final List<int> stepElapsedTimes;
  final List<PreparationStateEnum> preparationStepStates;
  final VoidCallback onSkip;

  const _PreparationStepListSection({
    required this.preparationSteps,
    required this.currentStepIndex,
    required this.stepElapsedTimes,
    required this.preparationStepStates,
    required this.onSkip,
  });
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
                preparationSteps: preparationSteps,
                currentStepIndex: currentStepIndex,
                stepElapsedTimes: stepElapsedTimes,
                preparationStepStates: preparationStepStates,
                onSkip: onSkip,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EndPreparationButtonSection extends StatelessWidget {
  final VoidCallback onEndPreparation;

  const _EndPreparationButtonSection({
    required this.onEndPreparation,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: ElevatedButton(
          onPressed: onEndPreparation,
          child: Text(AppLocalizations.of(context)!.finishPreparation),
        ),
      ),
    );
  }
}
