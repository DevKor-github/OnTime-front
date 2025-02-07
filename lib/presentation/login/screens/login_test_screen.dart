import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/login/components/google_login_button.dart';
import 'package:on_time_front/presentation/login/components/kakao_login_button.dart';

class LoginTestScreen extends StatelessWidget {
  const LoginTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          GoogleLoginButton(),
          KakaoLoginButton(),
        ],
      ),
    );
  }
}
