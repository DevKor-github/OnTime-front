import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

class GoogleSignInButton extends StatelessWidget {
  GoogleSignInButton({super.key});

  final Widget googleIconSvg = SvgPicture.asset(
    'google_icon.svg',
    package: 'assets',
    semanticsLabel: 'Google Icon',
    fit: BoxFit.contain,
  );

  @override
  Widget build(BuildContext context) {
    final UserRepository authenticationRepository = getIt.get<UserRepository>();
    return GestureDetector(
      onTap: () async {
        try {
          final googleAccout =
              await authenticationRepository.googleSignIn.signIn();
          if (googleAccout == null) {
            throw Exception('Google Sign In Failed, Sign In Accout is null');
          }
          await authenticationRepository.signInWithGoogle(googleAccout);
        } catch (e) {
          debugPrint(e.toString());
        }
      },
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
