import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final UserRepository authenticationRepository = getIt.get<UserRepository>();

    return SizedBox(
      width: 358,
      height: 54,
      child: ElevatedButton(
        onPressed: () async {
          try {
            final googleAccount =
                await authenticationRepository.googleSignIn.signIn();
            if (googleAccount == null) {
              throw Exception('Google Sign In Failed, Sign In Account is null');
            }
            await authenticationRepository.signInWithGoogle(googleAccount);
          } catch (e) {
            debugPrint(e.toString());
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Color(0xFFDADCE0), width: 1),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'google_icon.svg',
              package: 'assets',
              semanticsLabel: 'Google Icon',
              fit: BoxFit.contain,
              width: 20,
              height: 20,
            ),
            SizedBox(width: 10),
            Text(
              'Sign in with Google',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 21,
                height: 1.4,
                letterSpacing: 0,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
