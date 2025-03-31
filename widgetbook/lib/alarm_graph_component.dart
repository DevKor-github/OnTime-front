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
    min: 0,
    max: 1,
  );

  return Scaffold(
    backgroundColor: const Color(0xff5C79FB),
    body: SizedBox(
      height: 700,
      child: Center(
        child: CustomPaint(
          size: const Size(230, 115),
          painter: AlarmGraphComponent(progress: progress),
        ),
      ),
    ),
  );
}
