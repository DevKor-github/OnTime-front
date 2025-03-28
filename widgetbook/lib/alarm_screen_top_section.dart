import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/alarm/components/alarm_screen_top_section.dart';

@widgetbook.UseCase(
  name: 'Default',
  type: AlarmScreenTopSection,
)
Widget alarmScreenTopSectionUseCase(BuildContext context) {
  final isLate = context.knobs.boolean(label: 'Is Late', initialValue: false);
  final beforeOutTime = context.knobs.int.slider(
    label: 'Before Out Time (sec)',
    initialValue: 180,
    min: 0,
    max: 600,
  );
  final preparationName = context.knobs.string(
    label: 'Preparation Name',
    initialValue: '세수하기',
  );
  final remainingTime = context.knobs.int.slider(
    label: 'Remaining Time (sec)',
    initialValue: 120,
    min: 0,
    max: 600,
  );
  final progress = context.knobs.double.slider(
    label: 'Progress',
    initialValue: 0.5,
    max: 1,
    min: 0,
  );

  return Container(
    color: const Color(0xff5C79FB),
    child: AlarmScreenTopSection(
      isLate: isLate,
      beforeOutTime: beforeOutTime,
      preparationName: preparationName,
      preparationRemainingTime: remainingTime,
      progress: progress,
    ),
  );
}
