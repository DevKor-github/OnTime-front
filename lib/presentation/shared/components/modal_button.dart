import 'package:flutter/material.dart';

class ModalButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color? color;
  final Color? textColor;
  final TextStyle? textStyle;

  const ModalButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.textColor,
    this.color,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: SizedBox(
        width: 114,
        height: 43,
        child: Center(
          child: Text(
            text,
            style: textStyle ?? TextStyle(color: textColor),
          ),
        ),
      ),
    );
  }
}
