import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class PreparationStepTile extends StatelessWidget {
  const PreparationStepTile({
    super.key,
    required this.stepIndex,
    required this.preparationName,
    required this.preparationTime,
    required this.isLastItem,
    this.onSkip,
    required this.stepElapsedTime,
    this.stepRemainingTime,
    required this.preparationStepState,
  });

  final int stepIndex;
  final String preparationName;
  final String preparationTime;
  final bool isLastItem;
  final VoidCallback? onSkip;
  final int stepElapsedTime;
  final int? stepRemainingTime;
  final PreparationStateEnum preparationStepState;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = preparationStepState == PreparationStateEnum.now;
    final done = preparationStepState == PreparationStateEnum.done;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final displayTime = preparationStepState == PreparationStateEnum.yet
        ? preparationTime
        : formatElapsedTime(
            active ? stepRemainingTime ?? stepElapsedTime : stepElapsedTime,
          );
    final time = Text(
      displayTime,
      style: TextStyle(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: colors.primary,
      ),
    );
    final badge = SizedBox.square(
      dimension: 34,
      child: Center(
        child: Container(
          width: done ? 30 : 34,
          height: done ? 30 : 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.green : colors.primaryContainer,
          ),
          child: done
              ? SvgPicture.asset(
                  'runtime_step_check.svg',
                  package: 'assets',
                  semanticsLabel: '완료',
                  width: 24,
                  height: 24,
                )
              : Text(
                  '$stepIndex',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: colors.onPrimaryContainer,
                  ),
                ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: active && onSkip != null ? 135 : 62,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: active
                  ? Border.all(color: colors.primary, width: 2)
                  : null,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: active ? 14 : 16,
              vertical: active ? 12 : 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    badge,
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        preparationName,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!largeText) ...[const SizedBox(width: 8), time],
                  ],
                ),
                if (largeText)
                  Align(alignment: Alignment.centerRight, child: time),
                if (active && onSkip != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(53),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: Theme.of(context).textTheme.labelLarge!
                            .copyWith(
                              fontSize: 18,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      child: const Text(
                        '이 단계 건너 뛰기',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!isLastItem)
          Padding(
            padding: const EdgeInsets.only(left: 33),
            child: Container(width: 2, height: 14, color: colors.primary),
          ),
      ],
    );
  }
}
