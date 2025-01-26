import 'dart:math';

import 'package:flutter/material.dart';

class ArcIndicator extends CustomPainter {
  final double progress; // 전체 진행률
  final double strokeWidth; // 호의 두께

  ArcIndicator({
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double startAngle = 3.14 - (30 * 3.14 / 180);
    final double sweepAngle = 3.14 * 2 - (60 * 3.14 / 90);

    double arcDiameter = min(size.width, size.height) - strokeWidth;

    // 채워지기 전 색
    final Paint backgroundPaint = Paint()
      ..color = const Color(0xffd9d9d9)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 채워진 후 색
    final Paint progressPaint = Paint()
      ..color = const Color(0xff5C79FB)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, arcDiameter / 2 + strokeWidth / 2),
      width: arcDiameter,
      height: arcDiameter,
    );

    // 그래프 배경 호
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // 그래프 채워진 호
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
