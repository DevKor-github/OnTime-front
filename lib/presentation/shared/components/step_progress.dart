import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class StepProgress extends StatelessWidget {
  const StepProgress(
      {super.key,
      required this.currentStep,
      required this.totalSteps,
      this.singleLine = false});

  final int currentStep;
  final int totalSteps;

  /// If true, the step string will be displayed in a single line
  final bool singleLine;

  final double circleRadius = 11;

  Color _getIndicatorColor(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    if (currentStep >= index) {
      return colorScheme.primary;
    } else {
      return colorScheme.outlineVariant;
    }
  }

  Widget _buildIndicator(BuildContext context, int index) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: _IndicatorCircle(
            color: _getIndicatorColor(context, index),
            radius: circleRadius,
            filled: index != currentStep,
          ),
        ),
        if (index != totalSteps - 1)
          Expanded(
            child: _IndicatorLine(
              color: _getIndicatorColor(context, index + 1),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final textPainter = TextPainter(
              text: TextSpan(
                text: 'STEP${singleLine ? ' ' : '\n'}1',
                style: textTheme.bodyExtraSmall,
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            final textWidth = textPainter.size.width;

            return Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: textWidth / 2 - circleRadius / 2 - 6),
              child: Row(
                children: [
                  for (int i = 0; i < totalSteps - 1; i++)
                    Expanded(child: _buildIndicator(context, i)),
                  _buildIndicator(context, totalSteps - 1)
                ],
              ),
            );
          },
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < totalSteps; i++)
              _StepText(
                step: i + 1,
                singleLine: singleLine,
                style: textTheme.bodyExtraSmall.copyWith(
                  color: _getIndicatorColor(context, i),
                ),
              )
          ],
        )
      ],
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText({
    required this.step,
    required this.singleLine,
    this.style,
  });

  final int step;
  final bool singleLine;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      'STEP${singleLine ? ' ' : '\n'}$step',
      textAlign: TextAlign.center,
      style: style,
    );
  }
}

class _IndicatorLine extends StatelessWidget {
  const _IndicatorLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      color: color,
    );
  }
}

class _IndicatorCircle extends StatelessWidget {
  const _IndicatorCircle({
    required this.color,
    required this.radius,
    required this.filled,
  });

  final Color color;
  final double radius;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: 1.5,
        ),
        color: filled ? color : Colors.transparent,
      ),
    );
  }
}
