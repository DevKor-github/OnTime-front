import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../components/google_sign_in_button/shared.dart';
import '../components/google_sign_in_button/apple_sign_in_button_mobile.dart';

typedef SocialSignInAction = Future<void> Function();

class SignInMainScreen extends StatefulWidget {
  const SignInMainScreen({super.key, this.onAppleSignIn, this.onGoogleSignIn});

  final SocialSignInAction? onAppleSignIn;
  final SocialSignInAction? onGoogleSignIn;

  @override
  State<SignInMainScreen> createState() => _SignInMainScreenState();
}

class _SignInMainScreenState extends State<SignInMainScreen> {
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Title(),
            SizedBox(height: 48),
            _CharacterImage(),
            SizedBox(height: 41),
            if (!kIsWeb && Platform.isIOS) ...[
              AppleSignInButton(
                onPressed: _isSigningIn
                    ? null
                    : () => _startSignIn(
                        widget.onAppleSignIn ?? _defaultAppleSignIn,
                      ),
              ),
              SizedBox(height: 16),
            ],
            GoogleSignInButton(
              onPressed: _isSigningIn
                  ? null
                  : () => _startSignIn(
                      widget.onGoogleSignIn ?? _defaultGoogleSignIn,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSignIn(SocialSignInAction signIn) async {
    if (_isSigningIn) {
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    try {
      await signIn();
    } catch (error, stackTrace) {
      if (_isUserCancellation(error)) {
        AppLogger.debug(
          'Social sign-in canceled errorType=${error.runtimeType}',
        );
        return;
      }

      AppLogger.debug(
        'Social sign-in failed errorType=${error.runtimeType} '
        'stackTrace=$stackTrace',
      );
      if (mounted) {
        _restoreSignInButtons();
        await _showSignInFailureDialog();
      }
    } finally {
      if (mounted && _isSigningIn) {
        _restoreSignInButtons();
      }
    }
  }

  void _restoreSignInButtons() {
    setState(() {
      _isSigningIn = false;
    });
  }

  Future<void> _defaultGoogleSignIn() async {
    final userRepository = getIt.get<UserRepository>();
    final googleAccount = await userRepository.authenticateWithGoogle();
    await userRepository.signInWithGoogle(googleAccount);
  }

  Future<void> _defaultAppleSignIn() async {
    final userRepository = getIt.get<UserRepository>();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final fullNameRaw =
        '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
    final fullName = fullNameRaw.isNotEmpty ? fullNameRaw : 'Apple User';

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
  }

  bool _isUserCancellation(Object error) {
    return error is GoogleSignInException &&
            error.code == GoogleSignInExceptionCode.canceled ||
        error is SignInWithAppleAuthorizationException &&
            error.code == AuthorizationErrorCode.canceled;
  }

  Future<void> _showSignInFailureDialog() {
    final l10n = AppLocalizations.of(context)!;

    return showTwoActionDialog(
      context,
      config: TwoActionDialogConfig(
        title: l10n.signInFailedTitle,
        description: l10n.signInFailedDescription,
        primaryAction: DialogActionConfig(
          label: l10n.ok,
          variant: ModalWideButtonVariant.destructive,
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 28,
      children: [
        Image.asset('logo.png', package: 'assets', width: 167),
        Text(
          AppLocalizations.of(context)!.signInSlogan,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

class _CharacterImage extends StatelessWidget {
  const _CharacterImage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 241,
      child: SvgPicture.asset('characters/character.svg', package: 'assets'),
    );
  }
}

// class _SocialSignInButtonRow extends StatelessWidget {
//   const _SocialSignInButtonRow();

//   @override
//   Widget build(BuildContext context) {
//     final UserRepository authenticationRepository = getIt.get<UserRepository>();
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         GoogleSignInButton(
//           onPressed: () async {
//             await authenticationRepository.signInWithGoogle();
//           },
//         ),
//       ],
//     );
//   }
// }
