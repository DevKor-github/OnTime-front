import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';

class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({super.key});

  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  LoginPlatform _loginPlatform = LoginPlatform.none;

  final String _serverUrl = "http://your-server.com/api/auth/google";

  // Spring Boot로 로그인 요청을 보내는 메서드
  Future<void> _handleLogin(BuildContext context) async {
    try {
      // Spring Boot로 로그인 요청 전송
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // 서버로부터 받은 응답(JSON 파싱)
        final responseData = jsonDecode(response.body);

        print("로그인 성공: ${responseData['message']}");
        print("발급된 토큰: ${responseData['token']}");

        // 로그인 성공 시 상태 업데이트
        setState(() {
          _loginPlatform = LoginPlatform.google;
        });

        // TestScreen으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TestScreen(
              loginPlatform: LoginPlatform.google,
            ),
          ),
        );
      } else {
        // 서버 응답이 실패일 경우
        print("로그인 실패: ${response.body}");
        _showErrorDialog(context, "로그인 실패. 다시 시도해주세요.");
      }
    } catch (error) {
      // 요청 중 오류가 발생한 경우
      print("Error: $error");
      _showErrorDialog(context, "Network Error.");
    }
  }

  // 에러 표시
  void _showErrorDialog(BuildContext context, String message) {
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 로그인 버튼: Spring Boot로 요청만 보냄
        OutlinedButton(
          onPressed: () => _handleLogin(context),
          child: const Text('Google Login'),
        ),
      ],
    );
  }
}
