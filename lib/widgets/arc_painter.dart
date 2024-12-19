import 'dart:math';
import 'package:flutter/material.dart';

class ArcPainter extends CustomPainter {
  final double progress; // 전체 진행률
  final List<double> preparationRatios; // 준비 과정별 비율
  final List<bool> preparationCompleted; // 준비 과정 완료 여부

  ArcPainter({
    required this.progress,
    required this.preparationRatios,
    required this.preparationCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double startAngle = 3.14 - (50 * 3.14 / 180);
    final double sweepAngle = 3.14 * 2 - (40 * 3.14 / 90);

    // 채워지기 전 색
    final Paint backgroundPaint = Paint()
      ..color = const Color(0xffB0C4FB)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 채워진 후 색
    final Paint progressPaint = Paint()
      ..color = const Color(0xff5C79FB)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 준비 과정 마커 색상
    final Paint markerPaint = Paint()
      ..strokeWidth = 12
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height),
      width: size.width,
      height: size.height * 2,
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

    // 마커 배치 로직
    double cumulativeRatio = 0.0;
    for (int i = 0; i < preparationRatios.length; i++) {
      cumulativeRatio += preparationRatios[i]; // 누적 비율 계산

      final double angle = startAngle + (sweepAngle * cumulativeRatio); // 각도 계산

      final Offset markerPosition = Offset(
        size.width / 2 + (size.width / 2 - 8) * -cos(angle),
        size.height - (size.height - 8) * sin(angle),
      );

      markerPaint.color = preparationCompleted[i]
          ? const Color(0xff5C79FB) // 완료된 경우
          : const Color(0xffB0C4FB); // 완료되지 않은 경우

      // 마커 원 그리기
      canvas.drawCircle(markerPosition, 10, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
