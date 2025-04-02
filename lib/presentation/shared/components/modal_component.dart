import 'dart:ui';
import 'package:flutter/material.dart';

class ModalComponent extends StatelessWidget {
  final double containerWidth;
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
    required this.containerWidth,
  });

  @override
  Widget build(BuildContext context) {
    final double innerWidth = containerWidth * 0.85;
    final double buttonWidth = containerWidth * 0.4;

    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        Center(
          child: Container(
            width: containerWidth,
            height: 170,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: innerWidth,
              height: 132,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ModalTextsSection(
                      modalTitleText: modalTitleText,
                      modalDetailText: modalDetailText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _ModalButtonsSection(
                    leftPressed: leftPressed,
                    rightPressed: rightPressed,
                    leftButtonText: leftButtonText,
                    rightButtonText: rightButtonText,
                    leftButtonColor: leftButtonColor,
                    leftButtonTextColor: leftButtonTextColor,
                    rightButtonColor: rightButtonColor,
                    rightButtonTextColor: rightButtonTextColor,
                    buttonWidth: buttonWidth,
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModalTextsSection extends StatelessWidget {
  final String modalTitleText;
  final String modalDetailText;

  const _ModalTextsSection({
    required this.modalTitleText,
    required this.modalDetailText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          modalTitleText,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 10),
        Text(
          modalDetailText,
          style: const TextStyle(
            fontSize: 13,
          ),
          textAlign: TextAlign.left,
        ),
      ],
    );
  }
}

class _ModalButtonsSection extends StatelessWidget {
  final VoidCallback leftPressed;
  final VoidCallback rightPressed;
  final String leftButtonText;
  final String rightButtonText;
  final Color leftButtonColor;
  final Color leftButtonTextColor;
  final Color rightButtonColor;
  final Color rightButtonTextColor;
  final double buttonWidth;

  const _ModalButtonsSection({
    required this.leftPressed,
    required this.rightPressed,
    required this.leftButtonText,
    required this.rightButtonText,
    required this.leftButtonColor,
    required this.leftButtonTextColor,
    required this.rightButtonColor,
    required this.rightButtonTextColor,
    required this.buttonWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Button(
          onPressed: leftPressed,
          text: leftButtonText,
          backgroundColor: leftButtonColor,
          textColor: leftButtonTextColor,
          buttonWidth: buttonWidth,
        ),
        const SizedBox(width: 7),
        _Button(
          onPressed: rightPressed,
          text: rightButtonText,
          backgroundColor: rightButtonColor,
          textColor: rightButtonTextColor,
          buttonWidth: buttonWidth,
        ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final double buttonWidth;

  const _Button({
    required this.onPressed,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.buttonWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: buttonWidth,
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
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }
}
