import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';

class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({super.key});

  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  final String _loginUrl =
      "http://ejun.kro.kr:8888/oauth2/authorization/google"; // Spring Boot 엔드포인트
  LoginPlatform _loginPlatform = LoginPlatform.none;

  Future<void> _handleLogin() async {
    try {
      print("Spring Boot 서버로 Google OAuth 인증 요청 중: $_loginUrl");

      // 브라우저에서 Google 로그인 페이지 열기
      if (await canLaunch(_loginUrl)) {
        await launch(_loginUrl);

        final redirectedUrl =
            "http://ejun.kro.kr:8888/callback?token=abc123"; // 테스트용 URL
        final token = Uri.parse(redirectedUrl).queryParameters['token'];

        if (token == null || token.isEmpty) {
          throw Exception("토큰을 받을 수 없습니다.");
        }

        print("로그인 성공, 발급된 토큰: $token");

        // 토큰 저장
        await saveToken(token);

        // 로그인 성공 상태 업데이트
        setState(() {
          _loginPlatform = LoginPlatform.google;
        });

        // TestScreen으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TestScreen(loginPlatform: _loginPlatform),
          ),
        );
      } else {
        throw Exception("브라우저를 열 수 없습니다.");
      }
    } catch (error) {
      print("로그인 요청 중 에러 발생: $error");
      _showErrorDialog("로그인 중 에러 발생: $error");
    }
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    print("Token 저장 완료: $token");
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton(
        onPressed: _handleLogin,
        child: const Text('Google Login'),
      ),
    );
  }
}
