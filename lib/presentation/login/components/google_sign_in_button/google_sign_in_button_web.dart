import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final authenticationRepository = getIt.get<UserRepository>();
  @override
  void initState() {
    authenticationRepository.googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) {
      if (account != null) {
        getIt.get<UserRepository>().signInWithGoogle(account);
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return renderButton();
  }
}
