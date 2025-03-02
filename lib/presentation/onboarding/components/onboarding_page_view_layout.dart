import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_title.dart';

class OnboardingPageViewLayout extends StatefulWidget {
  const OnboardingPageViewLayout({
    super.key,
    required this.title,
    this.subTitle,
    this.hint,
    required this.child,
  });

  final String title;
  final String? hint;
  final RichText? subTitle;
  final Widget child;

  @override
  State<OnboardingPageViewLayout> createState() =>
      _OnboardingPageViewLayoutState();
}

class _OnboardingPageViewLayoutState extends State<OnboardingPageViewLayout> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 27.0, horizontal: 8.0),
          child: OnboardingTitle(
            title: widget.title,
            subTitle: widget.subTitle,
            hint: widget.hint,
          ),
        ),
        Expanded(
          child: widget.child,
        ),
      ],
    );
  }
}
