import 'package:flutter/material.dart';

class Marker extends StatelessWidget {
  final bool active; // 활성화 여부

  const Marker({
    super.key,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11, // 마커의 크기
      height: 11,
      decoration: BoxDecoration(
        color: active ? const Color(0xff5C79FB) : const Color(0xffB0C4FB),
        shape: BoxShape.circle,
      ),
    );
  }
}
