import 'package:flutter/material.dart';
import 'dart:math';

class MarkerWidget extends StatelessWidget {
  final double angle; // 마커의 각도
  final bool activated; // 활성화 여부
  final Offset center; // 중심 위치
  final double radius; // 반지름

  const MarkerWidget({
    super.key,
    required this.angle,
    required this.activated,
    required this.center,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    // 마커 위치 계산
    final Offset markerPosition = Offset(
      center.dx + radius * -cos(angle),
      center.dy - radius * sin(angle),
    );

    return Positioned(
      left: markerPosition.dx - 10, // 마커 크기에 따른 위치 조정
      top: markerPosition.dy - 10,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: activated ? const Color(0xff5C79FB) : const Color(0xffB0C4FB),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
