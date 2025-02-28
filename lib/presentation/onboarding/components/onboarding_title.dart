import 'package:flutter/material.dart';

class OnboardingTitle extends StatelessWidget {
  const OnboardingTitle({
    super.key,
    required this.title,
    this.subTitle,
    this.hint,
  });
  final String title;
  final String? hint;
  final RichText? subTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
            text: TextSpan(
                text: title,
                style: Theme.of(context).textTheme.titleLarge,
                children: hint != null
                    ? [
                        TextSpan(
                          text: hint,
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      ]
                    : [])),
        SizedBox(height: 8.0),
        subTitle ?? const SizedBox.shrink(),
      ],
    );
  }
}
