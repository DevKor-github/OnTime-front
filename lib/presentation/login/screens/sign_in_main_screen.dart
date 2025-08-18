import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

import '../components/google_sign_in_button/shared.dart';

class SignInMainScreen extends StatefulWidget {
  const SignInMainScreen({super.key});

  @override
  State<SignInMainScreen> createState() => _SignInMainScreenState();
}

class _SignInMainScreenState extends State<SignInMainScreen> {
  GoogleSignIn googleSignIn = GoogleSignIn();

  @override
  void initState() {
    googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        getIt.get<UserRepository>().signInWithGoogle(account);
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Title(),
            SizedBox(height: 48),
            _CharacterImage(),
            SizedBox(height: 24),
            GoogleSignInButton(),
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
      spacing: 8,
      children: [
        Text(AppLocalizations.of(context)!.appName,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            )),
        Text(AppLocalizations.of(context)!.signInSlogan,
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
    return SizedBox(
        height: 241,
        child: SvgPicture.asset(
          'characters/character.svg',
          package: 'assets',
        ));
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
