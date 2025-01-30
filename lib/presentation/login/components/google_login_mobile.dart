import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:on_time_front/presentation/login/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';

class GoogleLoginMobile extends StatefulWidget {
  const GoogleLoginMobile({super.key});

  @override
  State<GoogleLoginMobile> createState() => _GoogleLoginMobileState();
}

class _GoogleLoginMobileState extends State<GoogleLoginMobile> {
  final LoginPlatform _loginPlatform = LoginPlatform.none;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      GoogleSignInAccount? googleUser;

      // Android/iOS에서는 네이티브 Google 로그인 방식 사용
      googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        print("로그인 성공: ${googleUser.displayName}, 이메일: ${googleUser.email}");

        // Access Token
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? accessToken = googleAuth.accessToken;

        if (accessToken != null) {
          print("Access Token: $accessToken");

          // 여기서는 Google에서 제공한 사용자 정보를 사용하여 백엔드로 전달합니다
          final backendResponse = await http.post(
            // 백엔드 URI
            Uri.parse('http://ejun.kro.kr:8888/oauth2/google/registerOrLogin'),
            headers: {
              'Content-Type': 'application/json', // JSON 형식으로 전달
            },
            body: json.encode({
              'id': googleUser.id,
              'displayName': googleUser.displayName,
              'email': googleUser.email,
              'photoUrl': googleUser.photoUrl,
            }), // 필요한 사용자 정보를 body로 전달
          );

          if (backendResponse.statusCode == 200) {
            print("백엔드 처리 성공: ${backendResponse.headers}");

            // TestScreen으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const TestScreen(loginPlatform: LoginPlatform.google),
              ),
            );
          } else {
            print("Backend error: ${backendResponse.statusCode}");
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
