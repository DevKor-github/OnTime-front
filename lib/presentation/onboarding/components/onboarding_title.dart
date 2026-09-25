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
          textScaler: MediaQuery.textScalerOf(context),
          text: TextSpan(
            text: title,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 24,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
            children: hint != null
                ? [
                    TextSpan(
                      text: hint,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.grey.shade600,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        if (subTitle != null) ...[
          const SizedBox(height: 7),
          SizedBox(width: double.infinity, child: subTitle!),
        ],
      ],
    );
  }
}
