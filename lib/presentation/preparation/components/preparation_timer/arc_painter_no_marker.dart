import 'package:flutter/material.dart';
import 'dart:math' as math;

class ArcPainterNoMarker extends CustomPainter {
  final double progress; // 전체 진행률
  final List<double> preparationRatios; // 준비 과정별 비율
  final List<bool> preparationCompleted; // 준비 과정 완료 여부

  ArcPainterNoMarker({
    required this.progress,
    required this.preparationRatios,
    required this.preparationCompleted,
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
