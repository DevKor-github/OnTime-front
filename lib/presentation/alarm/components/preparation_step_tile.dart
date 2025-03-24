import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class PreparationStepTile extends StatelessWidget {
  final int stepIndex;
  final String preparationName;
  final String preparationTime;
  final bool isLastItem;
  final VoidCallback? onSkip;
  final int stepElapsedTime;
  final PreparationStateEnum preparationStepState;

  const PreparationStepTile({
    super.key,
    required this.stepIndex,
    required this.preparationName,
    required this.preparationTime,
    required this.isLastItem,
    this.onSkip,
    required this.stepElapsedTime,
    required this.preparationStepState,
  });

  @override
  Widget build(BuildContext context) {
    String displayTime;
    if (preparationStepState == PreparationStateEnum.yet) {
      displayTime = preparationTime;
    } else {
      displayTime = formatElapsedTime(stepElapsedTime);
    }

    Widget circleContent = (preparationStepState == PreparationStateEnum.done)
        ? const Icon(Icons.check, color: Color(0xff5C79FB))
        : Text(
            '$stepIndex',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xff212F6F),
            ),
          );

    Widget? skipButton;
    if (preparationStepState == PreparationStateEnum.now && onSkip != null) {
      skipButton = Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 326,
          height: 53,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xffDCE3FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onSkip,
            child: const Text(
              '이 단계 건너 뛰기',
              style: TextStyle(
                color: Color(0xff212F6F),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          child: Container(
            width: 358,
            height: (preparationStepState == PreparationStateEnum.now &&
                    skipButton != null)
                ? 135
                : 62,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: (preparationStepState == PreparationStateEnum.now)
                  ? Border.all(color: const Color(0xff5C79FB), width: 2)
                  : null,
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xffDCE3FF),
                            ),
                          ),
                          circleContent,
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          preparationName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        displayTime,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff5C79FB),
                        ),
                      ),
                    ],
                  ),
                  if (skipButton != null) ...[
                    const SizedBox(height: 20),
                    skipButton,
                  ]
                ],
              ),
            ),
          ),
        ),
        if (!isLastItem)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: DottedLine(
              direction: Axis.vertical,
              lineLength: 23,
              lineThickness: 3,
              dashColor: const Color(0xff5C79FB),
              dashLength: 4,
              dashGapLength: 5,
            ),
          ),
      ],
    );
  }
}
