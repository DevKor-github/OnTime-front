import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';

class KakaoLoginButton extends StatefulWidget {
  const KakaoLoginButton({super.key});

  @override
  State<KakaoLoginButton> createState() => _KakaoLoginButtonState();
}

class _KakaoLoginButtonState extends State<KakaoLoginButton> {
  LoginPlatform _loginPlatform = LoginPlatform.none;

  final String _serverUrl =
      'http://ejun.kro.kr:8888/oauth2/authorization/kakao';

  // 로그인 요청
  Future<void> _handleSignIn(BuildContext context) async {
    try {
      // 요청 전송
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'}, // 요청 헤더
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("로그인 성공: ${responseData['message']}");
        print("발급된 토큰: ${responseData['token']}");

        setState(() {
          _loginPlatform = LoginPlatform.kakao;
        });

        // TestScreen으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TestScreen(
              loginPlatform: _loginPlatform,
            ),
          ),
        );
      } else {
        // 서버 응답 실패 처리
        print("로그인 실패: ${response.body}");
        _showErrorDialog(context, "로그인 실패. 다시 시도해주세요.");
      }
    } catch (error) {
      // 네트워크 오류 처리
      print("Error: $error");
      _showErrorDialog(context, "Network Error.");
    }
  }

  // 에러 메시지 표시
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
        OutlinedButton(
          onPressed: () => _handleSignIn(context), // Spring Boot로 요청
          child: const Text('Kakao Login'),
        )
      ],
    );
  }
}
