import 'dart:ui';
import 'package:flutter/material.dart';

class ModalComponent extends StatelessWidget {
  final VoidCallback leftPressed;
  final VoidCallback rightPressed;
  final String modalTitleText;
  final String modalDetailText;
  final String leftButtonText;
  final String rightButtonText;
  final Color leftButtonColor;
  final Color leftButtonTextColor;
  final Color rightButtonColor;
  final Color rightButtonTextColor;

  const ModalComponent({
    super.key,
    required this.leftPressed,
    required this.rightPressed,
    required this.modalTitleText,
    required this.modalDetailText,
    required this.leftButtonText,
    required this.rightButtonText,
    required this.leftButtonColor,
    required this.leftButtonTextColor,
    required this.rightButtonColor,
    required this.rightButtonTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
      child: AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: SizedBox(
          width: 276,
          height: 145,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Description Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modalTitleText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    modalDetailText,
                    style: const TextStyle(
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              // Buttons Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Button(
                    onPressed: leftPressed,
                    text: leftButtonText,
                    backgroundColor: leftButtonColor,
                    textColor: leftButtonTextColor,
                  ),
                  const SizedBox(width: 8),
                  _Button(
                    onPressed: rightPressed,
                    text: rightButtonText,
                    backgroundColor: rightButtonColor,
                    textColor: rightButtonTextColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _Button({
    required this.onPressed,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 114,
      height: 43,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(color: textColor, fontSize: 18),
        ),
      ),
    );
  }
}
