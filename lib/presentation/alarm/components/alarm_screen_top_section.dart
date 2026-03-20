import 'package:flutter/material.dart';

import 'package:on_time_front/presentation/alarm/components/alarm_graph_animator.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class AlarmScreenTopSection extends StatelessWidget {
  final bool isLate;
  final int beforeOutTime;
  final String preparationName;
  final bool showPreparationName;
  final int preparationRemainingTime;
  final double progress;

  const AlarmScreenTopSection({
    super.key,
    required this.isLate,
    required this.beforeOutTime,
    required this.preparationName,
    this.showPreparationName = true,
    required this.preparationRemainingTime,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _BeforeOutTimeText(
          isLate: isLate,
          beforeOutTime: beforeOutTime,
        ),
        _AlarmGraphSection(
          preparationName: preparationName,
          showPreparationName: showPreparationName,
          preparationRemainingTime: preparationRemainingTime,
          progress: progress,
          highlightColor: colorScheme.primaryContainer,
          graphBackgroundColor: isLate
              ? colorScheme.primaryContainer
              : colorScheme.onPrimaryContainer.withValues(alpha: 0.35),
          graphProgressColor: colorScheme.primaryContainer,
        ),
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
    final overdueText = formatTime(beforeOutTime.abs());
    return Padding(
      padding: const EdgeInsets.only(top: 75),
      child: Text(
        isLate
            ? '준비시간을 $overdueText 초과했어요'
            : '${formatTime(beforeOutTime)} 뒤에 나가야 해요',
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
  final String preparationName;
  final bool showPreparationName;
  final int preparationRemainingTime;
  final double progress;
  final Color highlightColor;
  final Color graphBackgroundColor;
  final Color graphProgressColor;

  const _AlarmGraphSection({
    required this.preparationName,
    required this.showPreparationName,
    required this.preparationRemainingTime,
    required this.progress,
    required this.highlightColor,
    required this.graphBackgroundColor,
    required this.graphProgressColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AlarmGraphAnimator(
            progress: progress,
            backgroundColor: graphBackgroundColor,
            progressColor: graphProgressColor,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showPreparationName) ...[
                  Text(
                    preparationName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: highlightColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  formatTimeTimer(preparationRemainingTime),
                  style: TextStyle(
                    fontSize: 35,
                    color: highlightColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
