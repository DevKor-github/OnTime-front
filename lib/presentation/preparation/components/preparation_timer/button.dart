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

/// 최종 버튼 위젯
class Button extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  // 버튼의 사이즈와 색상 지정
  final ButtonSize size;

  const Button({
    super.key,
    required this.text,
    required this.onPressed,
    this.size = ButtonSize.Giant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: TextButton(
        onPressed: onPressed,
        style: theme.textButtonTheme.style?.copyWith(
          backgroundColor: WidgetStatePropertyAll(colorScheme.primary),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        child: Text(
          text,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
