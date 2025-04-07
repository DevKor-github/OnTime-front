import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/notification_permission/components/step_container.dart';
import 'package:on_time_front/presentation/notification_permission/components/title.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';

class AddToHomeScreenGuideScreen extends StatelessWidget {
  const AddToHomeScreenGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: Column(
            children: [
              _TitleContainer(),
              SizedBox(
                height: 35,
              ),
              _StepListContainer()
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleContainer extends StatelessWidget {
  const _TitleContainer();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotificationGuideTitle(),
        const SizedBox(height: 50),
        _SubTitle(),
      ],
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: '알림을 허용하려면 우선\n온타임을 ',
          style: textTheme.titleExtraLarge.copyWith(
            color: colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: '홈 화면에 추가',
              style: textTheme.titleExtraLarge.copyWith(
                color: colorScheme.primary,
              ),
            ),
            TextSpan(
              text: '해야해요',
            ),
          ],
        ));
  }
}

class _StepListContainer extends StatelessWidget {
  const _StepListContainer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        StepContainer(
          step: 1,
          title: RichText(
            text: TextSpan(
              text: '화면 하단의 ',
              style: textTheme.titleLarge,
              children: [
                TextSpan(
                  text: '[공유버튼]',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                ),
                TextSpan(text: ' 클릭'),
              ],
            ),
          ),
          image: Image.asset(
            'guides/share_button_guide.png',
            package: 'assets',
          ),
        ),
      ],
    );
  }
}
