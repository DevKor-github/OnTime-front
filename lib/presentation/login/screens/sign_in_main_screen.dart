import 'package:flutter/material.dart';
import 'package:flutter_signin_button/button_list.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';

class SignInMainScreen extends StatelessWidget {
  const SignInMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _Title(),
            SizedBox(height: 24),
            _CharacterImage(),
            SizedBox(height: 24),
            _SocialSignInButtonRow()
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text('OnTime',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            )),
        Text('당신의 잃어버린 여유를 찾아드립니다.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
            )),
      ],
    );
  }
}

class _CharacterImage extends StatelessWidget {
  const _CharacterImage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 280, child: Image.asset('assets/character.png'));
  }
}

class _SocialSignInButtonRow extends StatelessWidget {
  const _SocialSignInButtonRow();

  @override
  Widget build(BuildContext context) {
    final AuthenticationRepository _authenticationRepository =
        getIt.get<AuthenticationRepository>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GoogleSignInButton(
          onPressed: () async {
            await _authenticationRepository.signInWithGoogle();
          },
        ),
      ],
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  GoogleSignInButton({super.key, required this.onPressed});

  final Widget googleIconSvg = SvgPicture.asset(
    'assets/google_icon.svg',
    semanticsLabel: 'Google Icon',
    fit: BoxFit.contain,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF747775)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(9.0),
          child: googleIconSvg,
        ),
      ),
    );
  }
}
