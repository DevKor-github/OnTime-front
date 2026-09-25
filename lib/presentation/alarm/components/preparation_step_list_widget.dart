import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_tile.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

class PreparationStepListWidget extends StatefulWidget {
  final List<PreparationStepEntity> preparationSteps;
  final int currentStepIndex;
  final List<int> stepElapsedTimes;
  final List<PreparationStateEnum> preparationStepStates;
  final Function onSkip;

  const PreparationStepListWidget({
    super.key,
    required this.preparationSteps,
    required this.currentStepIndex,
    required this.stepElapsedTimes,
    required this.preparationStepStates,
    required this.onSkip,
  });

  @override
  State<PreparationStepListWidget> createState() =>
      _PreparationStepListWidgetState();
}

class _PreparationStepListWidgetState extends State<PreparationStepListWidget> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _tileKeys = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.preparationSteps.length; i++) {
      _tileKeys[i] = GlobalKey();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrentStep(widget.currentStepIndex);
    });
  }

  @override
  void didUpdateWidget(covariant PreparationStepListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (int i = 0; i < widget.preparationSteps.length; i++) {
      _tileKeys.putIfAbsent(i, GlobalKey.new);
    }
    if (oldWidget.currentStepIndex != widget.currentStepIndex) {
      _scrollToCurrentStep(widget.currentStepIndex);
    }
  }

  Future<void> _scrollToCurrentStep(int currentStepIndex) async {
    if (currentStepIndex > 0) {
      final key = _tileKeys[currentStepIndex];
      if (key?.currentContext != null) {
        await Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 358,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount: widget.preparationSteps.length,
          itemBuilder: (context, index) {
            final preparation = widget.preparationSteps[index];

            return PreparationStepTile(
              key: _tileKeys[index],
              stepIndex: index + 1,
              preparationName: preparation.preparationName,
              preparationTime: formatTime(
                preparation.preparationTime.inSeconds,
              ),
              isLastItem: index == widget.preparationSteps.length - 1,
              stepElapsedTime: widget.stepElapsedTimes[index],
              stepRemainingTime:
                  (preparation.preparationTime.inSeconds -
                          widget.stepElapsedTimes[index])
                      .clamp(0, preparation.preparationTime.inSeconds),
              preparationStepState: widget.preparationStepStates[index],
              onSkip: () => widget.onSkip(),
            );
          },
        ),
      ),
    );
  }
}
