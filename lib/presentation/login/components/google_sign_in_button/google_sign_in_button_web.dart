import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/google_authentication_service.dart';
import 'package:on_time_front/domain/entities/google_auth_credential.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final googleAuthenticationService = getIt.get<GoogleAuthenticationService>();
  late final Stream<GoogleAuthCredential> _authenticationCredentials;
  StreamSubscription<GoogleAuthCredential>?
  _authenticationCredentialsSubscription;

  @override
  void initState() {
    _authenticationCredentials =
        googleAuthenticationService.authenticationCredentials;
    unawaited(googleAuthenticationService.initialize());
    _authenticationCredentialsSubscription = _authenticationCredentials.listen((
      credential,
    ) {
      unawaited(getIt.get<UserRepository>().signInWithGoogle(credential));
    });
    super.initState();
  }

  @override
  void dispose() {
    unawaited(_authenticationCredentialsSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return renderButton();
  }
}
