import 'package:flutter/material.dart';
import 'dart:math' as math;

class AlarmGraphComponent extends CustomPainter {
  final double progress; // 전체 진행률

  AlarmGraphComponent({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double startAngle = -math.pi / 2;
    final double sweepAngle = math.pi * 2;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height),
      width: size.width,
      height: size.height * 2,
    );

    // 채워지기 전 색
    final Paint backgroundPaint = Paint()
      ..color = const Color(0xff3D54BC)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 채워진 후 색
    final Paint progressPaint = Paint()
      ..color = const Color(0xffDCE3FF)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 그래프 배경 호
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    final double currentSweep = sweepAngle * (1.0 - progress);

    // 그래프 채워진 호
    canvas.drawArc(
      rect,
      startAngle,
      currentSweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
