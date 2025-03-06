import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';

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
  final double lineWidth = 57;

  Color _getIndicatorColor(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    if (currentStep >= index) {
      return colorScheme.primary;
    } else {
      return colorScheme.outlineVariant;
    }
  }

  List<Widget> _buildIndicator(BuildContext context, int index) {
    return [
      if (index != 0)
        _IndicatorLine(
          color: _getIndicatorColor(context, index),
          lineWidth: lineWidth,
        ),
      Padding(
        padding: EdgeInsets.all(circleRadius / 2),
        child: _IndicatorCircle(
            color: _getIndicatorColor(context, index),
            radius: circleRadius,
            filled: index != currentStep),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: totalSteps * (lineWidth + circleRadius + circleRadius) -
            lineWidth +
            10.0,
      ),
      child: Column(
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
                    horizontal: textWidth / 2 - circleRadius),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < totalSteps; i++)
                      ..._buildIndicator(context, i),
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
      ),
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
  const _IndicatorLine({required this.color, required this.lineWidth});

  final Color color;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        height: 2,
        color: color,
        constraints: BoxConstraints(maxWidth: lineWidth, minWidth: 10.0),
      ),
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
