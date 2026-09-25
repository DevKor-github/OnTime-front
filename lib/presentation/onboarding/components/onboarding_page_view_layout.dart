import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_title.dart';

class OnboardingPageViewLayout extends StatefulWidget {
  const OnboardingPageViewLayout({
    super.key,
    required this.title,
    this.subTitle,
    this.hint,
    required this.child,
    this.contentSpacing = 18,
  });

  final String title;
  final String? hint;
  final RichText? subTitle;
  final Widget child;
  final double contentSpacing;

  @override
  State<OnboardingPageViewLayout> createState() =>
      _OnboardingPageViewLayoutState();
}

class _OnboardingPageViewLayoutState extends State<OnboardingPageViewLayout> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .6),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 40,
                  bottom: widget.contentSpacing,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OnboardingTitle(
                    title: widget.title,
                    subTitle: widget.subTitle,
                    hint: widget.hint,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
