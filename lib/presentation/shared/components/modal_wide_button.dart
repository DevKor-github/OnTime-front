import 'package:flutter/material.dart';

class ModalWideButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color? color;
  final Color? textColor;
  final TextStyle? textStyle;
  final double width;
  final double height;

  const ModalWideButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.textColor,
    this.color,
    this.textStyle,
    this.width = 245,
    this.height = 43,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(color),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          ),
          alignment: Alignment.center,
          minimumSize: WidgetStateProperty.all(Size(width, height)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: textStyle ?? TextStyle(color: textColor),
        ),
      ),
    );
  }
}
