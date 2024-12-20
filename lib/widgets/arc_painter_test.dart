import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class ArcPainterTest extends CustomPainter {
  final double progress; // 전체 진행률
  final List<double> preparationRatios; // 준비 과정별 비율
  final int currentIndex; // 현재 활성화된 준비 과정 인덱스

  ArcPainterTest({
    required this.progress,
    required this.preparationRatios,
    required this.currentIndex,
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

    // 마커 표시
    for (int i = 0; i < preparationRatios.length; i++) {
      final double markerRatio = startAngle + preparationRatios[i];
      final double angle = startAngle + (sweepAngle * markerRatio);

      final Offset markerPosition = Offset(
        size.width / 2 + (size.width / 2) * -cos(angle),
        size.height - (size.height - 2.5) * sin(angle),
      );

      // 마커 활성화 상태
      final bool isActive = i <= currentIndex;

      // 마커를 캔버스에 직접 그리기
      _drawMarker(canvas, markerPosition, isActive);
    }
  }

  // 마커를 캔버스에 그리기
  void _drawMarker(Canvas canvas, Offset position, bool active) {
    final Paint markerPaint = Paint()
      ..color = active ? const Color(0xff5C79FB) : const Color(0xffB0C4FB)
      ..style = PaintingStyle.fill;

    // 원형 마커 그리기
    canvas.drawCircle(position, 11, markerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
