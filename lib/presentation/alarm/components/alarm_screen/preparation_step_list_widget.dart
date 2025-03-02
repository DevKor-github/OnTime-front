import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/bloc/alarm_screen/alarm_timer/alarm_timer_bloc.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_screen/preparation_step_tile.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PreparationStepListWidget extends StatefulWidget {
  final List<PreparationStepEntity> preparations;
  final Function onSkip;

  const PreparationStepListWidget({
    super.key,
    required this.preparations,
    required this.onSkip,
  });

  @override
  State<PreparationStepListWidget> createState() =>
      _PreparationStepListWidgetState();
}

class _PreparationStepListWidgetState extends State<PreparationStepListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentStep();
    });
  }

  void _scrollToCurrentStep() {
    final currentStepIndex =
        context.read<AlarmTimerBloc>().state.currentStepIndex;

    if (currentStepIndex >= 0 &&
        currentStepIndex < widget.preparations.length) {
      const double tileHeight = 135.0;
      final double listPaddingTop = MediaQuery.of(context).size.height * 0.05;

      double scrollOffset = (currentStepIndex * tileHeight) - listPaddingTop;
      scrollOffset =
          scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmTimerBloc, AlarmTimerState>(
      builder: (context, timerState) {
        return Center(
          child: SizedBox(
            width: 329,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.preparations.length,
              itemBuilder: (context, index) {
                final preparation = widget.preparations[index];

                return PreparationStepTile(
                  key: Key('$index'),
                  stepIndex: index + 1,
                  preparationName: preparation.preparationName,
                  preparationTime:
                      formatTime(preparation.preparationTime.inSeconds),
                  isLastItem: index == widget.preparations.length - 1,
                  onSkip: () {
                    context
                        .read<AlarmTimerBloc>()
                        .add(const TimerStepSkipped());
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
