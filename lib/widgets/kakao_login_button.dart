import 'dart:convert'; // JSON 디코딩용
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // HTTP 요청용
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';

class KakaoLoginButton extends StatefulWidget {
  const KakaoLoginButton({super.key});

  @override
  State<KakaoLoginButton> createState() => _KakaoLoginButtonState();
}

class _KakaoLoginButtonState extends State<KakaoLoginButton> {
  // 로그인 플랫폼
  LoginPlatform _loginPlatform = LoginPlatform.none;

  // Spring Boot 서버 URL
  final String _serverUrl = 'http://your-server.com/api/auth/kakao';

  // Spring Boot로 로그인 요청을 보내는 메서드
  Future<void> _handleSignIn(BuildContext context) async {
    try {
      // Spring Boot로 POST 요청 전송
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'}, // 요청 헤더
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("로그인 성공: ${responseData['message']}");
        print("발급된 토큰: ${responseData['token']}");

        setState(() {
          _loginPlatform = LoginPlatform.kakao; // 상태 업데이트
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
      print("오류 발생: $error");
      _showErrorDialog(context, "네트워크 오류가 발생했습니다.");
    }
  }

  // 에러 메시지 표시
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("오류"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("확인"),
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
