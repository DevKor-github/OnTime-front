import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/alarm/components/alarm_graph_animator.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class AlarmScreenTopSection extends StatelessWidget {
  const AlarmScreenTopSection({
    super.key,
    required this.isLate,
    required this.beforeOutTime,
    required this.preparationName,
    this.showPreparationName = true,
    required this.preparationRemainingTime,
    required this.progress,
  });

  final bool isLate;
  final int beforeOutTime;
  final String preparationName;
  final bool showPreparationName;
  final int preparationRemainingTime;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final foreground = isLate ? AppColors.red.shade900 : AppColors.white;
    final titleColor = isLate
        ? AppColors.grey.shade700
        : AppColors.blue.shade200;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final topPadding = math.max(
      24.0,
      math.min(67.0, MediaQuery.paddingOf(context).top + 23),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, 36),
        child: Column(
          children: [
            Text(
              isLate
                  ? '준비 시간을 ${formatTime(beforeOutTime.abs())} 초과했어요'
                  : '${formatTime(beforeOutTime)} 뒤에 나가야 돼요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: textScale > 1.3 ? 20 : 24,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, ringConstraints) {
                  final diameter = math.min(
                    268.0,
                    math.min(
                      ringConstraints.maxWidth,
                      ringConstraints.maxHeight,
                    ),
                  );
                  return Center(
                    child: SizedBox.square(
                      dimension: diameter,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: AlarmGraphAnimator(
                              progress: progress,
                              backgroundColor: isLate
                                  ? AppColors.red.shade100
                                  : AppColors.blue.shade700,
                              progressColor: foreground,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showPreparationName) ...[
                                    Text(
                                      preparationName,
                                      style: TextStyle(
                                        fontSize: 28,
                                        height: 1.4,
                                        fontWeight: FontWeight.w700,
                                        color: titleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    _countdown(preparationRemainingTime),
                                    style: TextStyle(
                                      fontSize: 48,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      color: foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _countdown(int seconds) {
    final value = seconds.abs();
    final minutes = value ~/ 60;
    final remainder = (value % 60).toString().padLeft(2, '0');
    if (minutes >= 60) {
      return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$remainder';
    }
    return '$minutes:$remainder';
  }
}
