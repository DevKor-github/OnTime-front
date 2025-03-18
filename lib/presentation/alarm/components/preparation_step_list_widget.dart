import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/presentation/alarm/components/preparation_step_tile.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class PreparationStepListWidget extends StatefulWidget {
  final List<PreparationStepEntity> preparationSteps;
  final int currentStepIndex;

  final Function onSkip;

  const PreparationStepListWidget({
    super.key,
    required this.preparationSteps,
    required this.currentStepIndex,
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
  }

  @override
  void didUpdateWidget(covariant PreparationStepListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStepIndex != widget.currentStepIndex) {
      _scrollToCurrentStep(widget.currentStepIndex);
    }
  }

  Future<void> _scrollToCurrentStep(int currentStepIndex) async {
    if (currentStepIndex > 1) {
      final key = _tileKeys[currentStepIndex - 1];
      if (key?.currentContext != null) {
        final RenderBox box =
            key!.currentContext!.findRenderObject() as RenderBox;
        final double targetOffset = box.localToGlobal(Offset.zero).dy +
            _scrollController.offset -
            (MediaQuery.of(context).size.height / 2) +
            (box.size.height / 2) -
            50;

        await _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 329,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: widget.preparationSteps.length,
          itemBuilder: (context, index) {
            final preparation = widget.preparationSteps[index];

            return PreparationStepTile(
              key: _tileKeys[index],
              stepIndex: index + 1,
              preparationName: preparation.preparationName,
              preparationTime:
                  formatTime(preparation.preparationTime.inSeconds),
              isLastItem: index == widget.preparationSteps.length - 1,
              onSkip: () => widget.onSkip(),
            );
          },
        ),
      ),
    );
  }
}
