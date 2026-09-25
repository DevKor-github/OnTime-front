import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class OnboardingStartScreen extends StatelessWidget {
  const OnboardingStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshTheme(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    (MediaQuery.sizeOf(context).height * .174 -
                            MediaQuery.paddingOf(context).top)
                        .clamp(24, 147),
                    16,
                    24,
                  ),
                  child: const Column(
                    children: [
                      _Title(),
                      SizedBox(height: 46),
                      _OnboardingCharacterImage(),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 13),
                child: _OnboardingStartButton(),
              ),
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
          AppLocalizations.of(context)!.welcome,
          key: Key('onboarding_start_title'),
          style: textTheme.headlineSmall,
        ),
        SizedBox(height: 9),
        Text(
          AppLocalizations.of(context)!.onboardingStartSubtitle,
          textAlign: TextAlign.center,
          key: Key('onboarding_start_subtitle'),
          style: textTheme.bodyLarge?.copyWith(color: const Color(0xFF777777)),
        ),
      ],
    );
  }
}

class _OnboardingCharacterImage extends StatelessWidget {
  const _OnboardingCharacterImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/design/onboarding_greeting.png',
      excludeFromSemantics: true,
      height: 280,
      width: 271,
      fit: BoxFit.contain,
    );
  }
}

class _OnboardingStartButton extends StatelessWidget {
  const _OnboardingStartButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        onPressed: () {
          context.go('/onboarding');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(AppLocalizations.of(context)!.start),
        ),
      ),
    );
  }
}
