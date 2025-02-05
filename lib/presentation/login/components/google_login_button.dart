import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:on_time_front/presentation/home/screens/home_screen.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';

import 'package:on_time_front/utils/login_platform.dart';

class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({super.key});

  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  final LoginPlatform _loginPlatform = LoginPlatform.none;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      // Google 계정 로그인
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        print("로그인 성공: ${googleUser.displayName}, 이메일: ${googleUser.email}");

        // Access Token
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? accessToken = googleAuth.accessToken;

        if (accessToken != null) {
          print("Access Token: $accessToken");

          // Google 사용자 정보 요청 (User Info API 호출)
          final userInfoResponse = await http.get(
            Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          );

          if (userInfoResponse.statusCode == 200) {
            final userInfo = json.decode(userInfoResponse.body);
            print("사용자 정보 가져오기 성공: $userInfo");

            final formattedUserInfo = {
              "sub": userInfo["sub"], // 고유 ID
              "name": userInfo["name"],
              "given_name": userInfo["given_name"],
              "family_name": userInfo["family_name"],
              "picture": userInfo["picture"],
              "email": userInfo["email"],
              "email_verified": userInfo["email_verified"]
            };

            // userInfo와 accessToken을 모두 헤더로 전달
            final backendResponse = await http.post(
              // 백엔드 URI
              Uri.parse(
                  'http://ejun.kro.kr:8888/oauth2/google/registerOrLogin'),
              headers: {
                'Content-Type': 'application/json', // JSON 형식으로 전달
              },
              body: json.encode(formattedUserInfo), // userInfo를 body로 전달
            );

            if (backendResponse.statusCode == 200) {
              // ✅ responseBody에서 message, role을 가져오도록 수정
              final responseBody = json.decode(backendResponse.body);
              final String? message = responseBody['message'];
              final String? role = responseBody['role'];

              print("백엔드 처리 성공: $message, Role: $role");

              if (role == "GUEST") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OnboardingScreen(),
                  ),
                );
              } else if (role == "USER") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(),
                  ),
                );
              }

              final String? backendToken =
                  backendResponse.headers['Authorization'];
              if (backendToken != null) {
                print("백엔드 토큰 저장: $backendToken");
              }
            } else {
              print("Backend error: ${backendResponse.statusCode}");
            }
          } else {
            print("User info request failed: ${userInfoResponse.statusCode}");
            _showErrorDialog("Failed to get Google user info");
          }
        } else {
          _showErrorDialog("Failed to get Google Access Token");
        }
      } else {
        print("Login Canceled");
      }
    } catch (error) {
      print("Login Failed: $error");
      _showErrorDialog("Google login error.");
    }
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => _handleSignIn(context),
          child: const Text('Google Login'),
        ),
      ],
    );
  }
}
