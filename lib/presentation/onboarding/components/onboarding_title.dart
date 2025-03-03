import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';

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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
            text: TextSpan(
                text: title,
                style: textTheme.titleLarge,
                children: hint != null
                    ? [
                        TextSpan(
                          text: hint,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.grey.shade600,
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
