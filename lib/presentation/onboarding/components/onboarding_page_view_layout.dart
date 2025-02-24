import 'package:flutter/material.dart';

class OnboardingPageViewLayout extends StatefulWidget {
  const OnboardingPageViewLayout(
      {super.key, required this.title, required this.child});

  final Widget title;
  final Widget child;

  @override
  State<OnboardingPageViewLayout> createState() =>
      _OnboardingPageViewLayoutState();
}

class _OnboardingPageViewLayoutState extends State<OnboardingPageViewLayout> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 27.0),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: widget.title,
            ),
          ),
        ),
        Expanded(
          child: widget.child,
        ),
      ],
    );
  }
}
