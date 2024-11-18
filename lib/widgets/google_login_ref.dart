import 'package:flutter/material.dart';
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleLoginRef extends StatelessWidget {
  final String loginUrl = "http://localhost:8080/oauth2/authorization/google";

  const GoogleLoginRef({super.key});

  // Google OAuth2 로그인 URL 실행 및 토큰 처리
  Future<void> _launchLoginUrl(BuildContext context) async {
    try {
      // 서버에 로그인 요청
      final response = await http.get(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // 서버 응답 처리 (JSON 파싱)
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];

        if (token != null && token.isNotEmpty) {
          print("로그인 성공, 토큰: $token");

          // TestScreen으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TestScreen(
                loginPlatform: LoginPlatform.google,
              ),
            ),
          );
        } else {
          // 토큰이 없는 경우 에러 처리
          _showErrorDialog(context, "로그인 실패: 유효한 토큰을 받지 못했습니다.");
        }
      } else {
        // 로그인 실패 처리
        print("로그인 실패: ${response.body}");
        _showErrorDialog(context, "로그인 실패. 다시 시도해주세요.");
      }
    } catch (error) {
      // 네트워크 또는 서버 오류 처리
      print("Error: $error");
      _showErrorDialog(context, "Network Error. 다시 시도해주세요.");
    }
  }

  // 에러 다이얼로그 표시
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
    return Center(
      child: ElevatedButton(
        onPressed: () => _launchLoginUrl(context),
        child: const Text('Google Login'),
      ),
    );
  }
}
