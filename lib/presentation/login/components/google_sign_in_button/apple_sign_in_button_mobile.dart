import 'package:flutter/material.dart' hide IconAlignment;
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/dio/api_error_message.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final UserRepository userRepository = getIt.get<UserRepository>();

    return SizedBox(
      width: 358,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
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
              final fullName = fullNameRaw.isNotEmpty
                  ? fullNameRaw
                  : 'Apple User';

              final identityToken = credential.identityToken;
              final authorizationCode = credential.authorizationCode;
              if (identityToken == null) {
                throw Exception('Apple Sign In Failed: Missing credentials');
              }

              await userRepository.signInWithApple(
                idToken: identityToken,
                authCode: authorizationCode,
                fullName: fullName,
                email: credential.email,
              );
            } catch (error, stackTrace) {
              AppLogger.debug(
                'Apple Sign-In button failed errorType=${error.runtimeType} '
                'message=$error stackTrace=$stackTrace',
              );
              if (!context.mounted) {
                return;
              }
              final message =
                  ApiErrorMessage.fromException(error) ??
                  'Apple 로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'appleid_button.png',
            package: 'assets',
            width: 358,
            height: 54,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
