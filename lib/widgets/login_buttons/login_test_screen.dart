import 'package:flutter/material.dart';
import 'package:on_time_front/widgets/login_buttons/google_login_button.dart';
import 'package:on_time_front/widgets/login_buttons/kakao_login_button.dart';

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
