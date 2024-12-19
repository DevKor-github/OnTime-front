import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String text;
  final double width; // width 추가
  final double height; // height 추가
  final VoidCallback onPressed;

  const Button({
    super.key,
    required this.text,
    this.width = 358, // 기본값 설정
    this.height = 58,
    required this.onPressed, // 기본값 설정
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // SizedBox를 사용하여 크기 지정
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff5C79FB),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8),
            ),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
