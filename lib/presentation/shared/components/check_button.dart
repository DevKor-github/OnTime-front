import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CheckButton extends StatelessWidget {
  CheckButton({super.key, required this.isChecked, required this.onPressed});

  final Widget svg = SvgPicture.asset(
    'assets/check.svg',
    semanticsLabel: 'check',
  );

  final bool isChecked;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(CircleBorder()),
          backgroundColor: WidgetStatePropertyAll(isChecked
              ? const Color.fromARGB(255, 0, 202, 120)
              : const Color.fromARGB(255, 232, 232, 232)),
          elevation: WidgetStateProperty.all(0), // Remove elevation changes
          shadowColor:
              WidgetStateProperty.all(Colors.transparent), // No shadow on press
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
        child: svg);
  }
}
