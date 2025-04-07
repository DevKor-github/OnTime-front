import 'package:flutter/material.dart';

class NotificationGuideTitle extends StatelessWidget {
  const NotificationGuideTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '온타임이 준비를 도와드릴 수 있도록',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.outline,
          ),
        ),
        Text(
          '알림을 허용해주세요',
          style: textTheme.headlineLarge?.copyWith(
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
