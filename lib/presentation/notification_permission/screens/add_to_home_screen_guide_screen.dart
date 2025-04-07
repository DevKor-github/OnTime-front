import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/notification_permission/components/step_container.dart';
import 'package:on_time_front/presentation/notification_permission/components/title.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';

class AddToHomeScreenGuideScreen extends StatelessWidget {
  const AddToHomeScreenGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 78.0) +
                EdgeInsets.symmetric(horizontal: 16),
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
    return Column(
      children: const [
        _Step1Container(),
        SizedBox(height: 28),
        _Step2Container(),
      ],
    );
  }
}

class _Step1Container extends StatelessWidget {
  const _Step1Container();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return StepContainer(
      step: 1,
      title: RichText(
        text: TextSpan(
          text: '화면 하단의 ',
          style: textTheme.titleLarge,
          children: [
            TextSpan(
              text: '[공유버튼]',
              style: textTheme.titleLarge?.copyWith(
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
    );
  }
}

class _Step2Container extends StatelessWidget {
  const _Step2Container();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return StepContainer(
      step: 2,
      title: RichText(
        text: TextSpan(
          text: '홈화면에 추가하기',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
          ),
          children: [
            TextSpan(
              text: '찾아서 선택',
              style: textTheme.titleLarge,
            ),
          ],
        ),
      ),
      image: Image.asset(
        'guides/add_to_home_screen_guide.png',
        package: 'assets',
      ),
    );
  }
}
