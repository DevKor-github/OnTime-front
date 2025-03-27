import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/alarm/components/alarm_graph_animator.dart';

@widgetbook.UseCase(
  name: 'Graph Progress Animation',
  type: AlarmGraphAnimator,
)
Widget alarmGraphAnimatorUseCase(BuildContext context) {
  final progress = context.knobs.double.slider(
    label: 'Progress',
    initialValue: 0.5,
    min: 0,
    max: 1,
  );

  return Container(
    color: const Color(0xff5C79FB),
    height: 190,
    alignment: Alignment.center,
    child: AlarmGraphAnimator(progress: progress),
  );
}
