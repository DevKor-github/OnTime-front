import 'package:flutter/material.dart';

/// 버튼 크기를 지정할 enum
enum ButtonSize {
  Giant,
  Large,
  Medium,
  Small,
  Tiny,
}

/// 각 버튼 크기에 맞는 너비/높이 정의
extension ButtonSizeExtension on ButtonSize {
  double get width {
    switch (this) {
      case ButtonSize.Giant:
        return 358;
      case ButtonSize.Large:
        return 249;
      case ButtonSize.Medium:
        return 199;
      case ButtonSize.Small:
        return 149;
      case ButtonSize.Tiny:
        return 99;
    }
  }

  double get height {
    switch (this) {
      case ButtonSize.Giant:
        return 58;
      case ButtonSize.Large:
        return 53;
      case ButtonSize.Medium:
        return 48;
      case ButtonSize.Small:
        return 43;
      case ButtonSize.Tiny:
        return 38;
    }
  }
}

/// 버튼 색상을 지정할 enum
enum ButtonColor {
  Blue,
  LightBlue,
  Gray,
}

/// 각 배경색에 대응되는 실제 색상 및 텍스트 색상
extension ButtonColorExtension on ButtonColor {
  Color get backgroundColor {
    switch (this) {
      case ButtonColor.Blue:
        return const Color(0xff5C79FB);
      case ButtonColor.LightBlue:
        return const Color(0xffDCE3FF);
      case ButtonColor.Gray:
        return const Color(0xffDFDFDF);
    }
  }

  Color get textColor {
    switch (this) {
      case ButtonColor.Blue:
        return Colors.white; // #FFFFFF
      case ButtonColor.LightBlue:
        return const Color(0xff5C79FB);
      case ButtonColor.Gray:
        return Colors.white; // #FFFFFF
    }
  }
}

/// 최종 버튼 위젯
class Button extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  // 버튼의 사이즈와 색상 지정
  final ButtonSize size;
  final ButtonColor color;

  /// 디폴트 값:
  ///  - size = ButtonSize.Giant
  ///  - color = ButtonColor.Blue
  ///  - 그때 textColor는 자동으로 White
  const Button({
    super.key,
    required this.text,
    required this.onPressed,
    this.size = ButtonSize.Giant,
    this.color = ButtonColor.Blue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: color.backgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8),
            ),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(color: color.textColor),
        ),
      ),
    );
  }
}
