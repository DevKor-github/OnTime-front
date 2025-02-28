import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_title.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'default',
  type: OnboardingTitle,
)
Widget useCaseOnboardingTitle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return OnboardingTitle(
    title: context.knobs
        .string(label: 'Title', initialValue: '약속에 나가기 위한 준비 과정을\n선택해주세요'),
    subTitle: RichText(
        text: TextSpan(
      text: context.knobs
          .string(label: 'SubTitle', initialValue: '설정한 여유시간만큼 일찍 도착할 수 있어요.'),
      style: TextStyle(
        color: colorScheme.outline,
        fontSize: 16,
      ),
    )),
    hint: context.knobs.stringOrNull(label: 'Hint', initialValue: '(중복 가능)'),
  );
}
