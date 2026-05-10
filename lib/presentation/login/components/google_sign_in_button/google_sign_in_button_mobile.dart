import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    final UserRepository authenticationRepository = getIt.get<UserRepository>();
    final canSignIn = context.select<AuthBloc, bool>(
      (bloc) => bloc.state.status == AuthStatus.unauthenticated,
    );

    return SizedBox(
      width: 358,
      height: 54,
      child: ElevatedButton(
        onPressed: !canSignIn || _isSigningIn
            ? null
            : () async {
                setState(() {
                  _isSigningIn = true;
                });
                try {
                  final googleAccount = await authenticationRepository
                      .authenticateWithGoogle();
                  await authenticationRepository.signInWithGoogle(
                    googleAccount,
                  );
                } catch (error) {
                  AppLogger.debug(
                    'Google Sign-In button failed errorType=${error.runtimeType}',
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _isSigningIn = false;
                    });
                  }
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
