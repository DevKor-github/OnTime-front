import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleLogin extends StatelessWidget {
  const AppleLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apple Login'),
      ),
      body: Center(
        child: SignInWithAppleButton(
          onPressed: () async {
            final credential = await SignInWithApple.getAppleIDCredential(
              scopes: [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
            );

            /// 사용자 이메일
            /// 사용자 설정에 따라서 비공개 이메일이 올 수 있음.
            /// 첫 로그인시에만 오고 그 후로는 null 반환.
            print(credential.email ?? '');

            /// 사용자 이름 (성)
            /// 첫 로그인시에만 오고 그 후로는 null 반환.
            print(credential.familyName ?? '');

            /// 사용자 이름 (이름)
            /// 첫 로그인시에만 오고 그 후로는 null 반환.
            print(credential.givenName ?? '');

            /// Apple에서 발급하는 해당앱의 유저 고유 식별자.
            print(credential.userIdentifier ?? '');

            /// Apple에서 발급하는 JWT 형식의 신원 확인 토큰.
            print(credential.identityToken);

            /// 짧은 기간 유효한 인증 코드로, 서버에서 Apple과 통신해 사용자 인증을 확인할 때 사용됩니다.
            print(credential.authorizationCode);

            // Now send the credential (especially `credential.authorizationCode`) to your server to create a session
            // after they have been validated with Apple (see `Integration` section for more information on how to do this)
          },
        ),
      ),
    );
  }
}
