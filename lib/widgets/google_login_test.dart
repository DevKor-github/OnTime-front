import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';

class GoogleLoginTest extends StatefulWidget {
  const GoogleLoginTest({super.key});

  @override
  State<GoogleLoginTest> createState() => _GoogleLoginTestState();
}

class _GoogleLoginTestState extends State<GoogleLoginTest> {
  LoginPlatform _loginPlatform = LoginPlatform.none;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      // Google 로그인
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        print("로그인 성공: ${googleUser.displayName}, 이메일: ${googleUser.email}");

        // Access Token 획득
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? accessToken = googleAuth.accessToken;

        if (accessToken != null) {
          print("Access Token: $accessToken");

          // Google 사용자 정보 요청 (Access Token을 헤더에 포함)
          final response = await http.get(
            Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          );

          if (response.statusCode == 200) {
            final userInfo = json.decode(response.body);
            print("사용자 정보 가져오기 성공: $userInfo");

            // 사용자 정보 상세 출력
            print("Google 사용자 정보:");
            print(userInfo);
          } else {
            print("사용자 정보 가져오기 실패: ${response.statusCode}");
          }

          setState(() {
            _loginPlatform = LoginPlatform.google;
          });

          // TestScreen으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const TestScreen(loginPlatform: LoginPlatform.google)),
          );
        } else {
          print("Access Token을 가져오지 못했습니다.");
        }
      } else {
        print("로그인 취소됨");
      }
    } catch (error) {
      print("로그인 실패: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => _handleSignIn(context),
          child: const Text('Google TEST'),
        ),
      ],
    );
  }
}
