import 'package:flutter/material.dart' hide IconAlignment;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final UserRepository userRepository = getIt.get<UserRepository>();

    return SizedBox(
      width: 358,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          height: 24 / 19,
          fontFamily: 'SF Pro',
        ),
        child: SignInWithAppleButton(
          onPressed: () async {
            try {
              final credential = await SignInWithApple.getAppleIDCredential(
                scopes: [
                  AppleIDAuthorizationScopes.email,
                  AppleIDAuthorizationScopes.fullName,
                ],
              );

              final fullNameRaw =
                  '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                      .trim();
              final fullName =
                  fullNameRaw.isNotEmpty ? fullNameRaw : 'Apple User';

              final identityToken = credential.identityToken;
              final authorizationCode = credential.authorizationCode;
              if (identityToken == null || authorizationCode == null) {
                throw Exception('Apple Sign In Failed: Missing credentials');
              }

              await userRepository.signInWithApple(
                idToken: identityToken,
                authCode: authorizationCode,
                fullName: fullName,
                email: credential.email,
              );
            } catch (e) {
              debugPrint('Apple Sign In Error: ${e.toString()}');
            }
          },
          style: SignInWithAppleButtonStyle.black,
          height: 54,
          borderRadius: BorderRadius.circular(14),
          iconAlignment: IconAlignment.center,
          text: 'Sign in with Apple',
        ),
      ),
    );
  }
}
