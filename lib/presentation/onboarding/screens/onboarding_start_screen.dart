import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';

class OnboardingStartScreen extends StatelessWidget {
  const OnboardingStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 35),
        child: Center(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Title(),
                      SizedBox(height: 37),
                      _CharacterImage(),
                    ],
                  ),
                ),
              ),
              _OnboardingStartButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '반가워요!',
          key: Key('onboarding_start_title'),
          style: textTheme.headlineSmall,
        ),
        Text(
          'Ontime과 함께 준비하기 위해서\n평소 본인의 준비 과정을 알려주세요',
          textAlign: TextAlign.center,
          key: Key('onboarding_start_subtitle'),
          style: textTheme.titleSmall?.copyWith(color: AppColors.grey.shade700),
        ),
      ],
    );
  }
}

class _CharacterImage extends StatelessWidget {
  const _CharacterImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/character_greeting.png',
      height: 280,
    );
  }
}

class _OnboardingStartButton extends StatelessWidget {
  const _OnboardingStartButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.push('/onboarding');
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('시작하기'),
        ),
      ),
    );
  }
}
