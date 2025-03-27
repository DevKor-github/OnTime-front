import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/alarm/components/alarm_graph_component.dart';

@widgetbook.UseCase(
  name: 'Static Graph Painter',
  type: AlarmGraphComponent,
)
Widget alarmGraphComponentUseCase(BuildContext context) {
  final progress = context.knobs.double.slider(
    label: 'Progress',
    initialValue: 0.5,
    max: 1,
    min: 0,
  );

  return CustomPaint(
    size: const Size(230, 115),
    painter: AlarmGraphComponent(progress: progress),
  );
}
