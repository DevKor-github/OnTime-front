import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // 카카오 SDK 추가

class KakaoLoginButton extends StatefulWidget {
  const KakaoLoginButton({super.key});

  @override
  State<KakaoLoginButton> createState() => _KakaoLoginButtonState();
}

class _KakaoLoginButtonState extends State<KakaoLoginButton> {
  LoginPlatform _loginPlatform = LoginPlatform.none;

  final String _serverUrl =
      'http://ejun.kro.kr:8888/oauth2/authorization/kakao';

  // 카카오 로그인 처리
  Future<void> _handleKakaoLogin(BuildContext context) async {
    try {
      // 카카오톡 설치 여부 확인
      bool talkInstalled = await isKakaoTalkInstalled();

      String authCode;

      if (talkInstalled) {
        // 카카오톡으로 로그인
        try {
          authCode = await AuthCodeClient.instance.authorizeWithTalk(
            redirectUri:
                "http://localhost:8888/oauth/kakao/callback", // 리다이렉트 URI
          );
        } catch (error) {
          print('카카오톡으로 로그인 실패: $error');
          _showErrorDialog(context, '카카오톡으로 로그인에 실패했습니다.');
          return;
        }
      } else {
        // 카카오 계정으로 로그인
        try {
          authCode = await AuthCodeClient.instance.authorize(
            redirectUri: "http://localhost:8888/oauth/kakao/callback",
          );
        } catch (error) {
          print('카카오 계정으로 로그인 실패: $error');
          _showErrorDialog(context, '카카오 계정으로 로그인에 실패했습니다.');
          return;
        }
      }

      // 서버에 인증 코드 전달
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authCode': authCode}),
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
        print("로그인 실패: ${response.body}");
        _showErrorDialog(context, "로그인 실패. 다시 시도해주세요.");
      }
    } catch (error) {
      print("에러 발생: $error");
      _showErrorDialog(context, "네트워크 오류가 발생했습니다.");
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
          onPressed: () => _handleKakaoLogin(context), // 카카오 로그인 실행
          child: const Text('Kakao Login'),
        )
      ],
    );
  }
}
