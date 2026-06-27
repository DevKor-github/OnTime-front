import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final authenticationRepository = getIt.get<UserRepository>();
  late final Stream<GoogleSignInAuthenticationEvent> _authenticationEvents;
  StreamSubscription<GoogleSignInAuthenticationEvent>?
  _authenticationEventsSubscription;

  @override
  void initState() {
    _authenticationEvents = authenticationRepository.googleAuthenticationEvents;
    unawaited(authenticationRepository.initializeGoogleSignIn());
    _authenticationEventsSubscription = _authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        unawaited(getIt.get<UserRepository>().signInWithGoogle(event.user));
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    unawaited(_authenticationEventsSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return renderButton();
  }
}
