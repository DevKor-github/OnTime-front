import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:on_time_front/main.dart';
import 'package:on_time_front/utils/login_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestScreen extends StatelessWidget {
  final LoginPlatform loginPlatform; // 로그인 플랫폼

  const TestScreen({
    super.key,
    required this.loginPlatform,
  }) : assert(loginPlatform != LoginPlatform.none,
            "loginPlatform cannot be null.");

  // 로그아웃 처리
  Future<void> _handleLogout(BuildContext context) async {
    try {
      // 로그인 플랫폼에 따라 로그아웃 처리
      if (loginPlatform == LoginPlatform.google) {
        // Google 로그아웃 처리
        await GoogleSignIn().signOut();
      } else if (loginPlatform == LoginPlatform.kakao) {
        // Kakao 로그아웃 처리
        await UserApi.instance.logout();
      }

      // JWT 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');

      // 로그아웃 후 MyApp으로 이동
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MyApp()), // MyApp으로 이동
        (route) => false,
      );
    } catch (error) {
      print("로그아웃 실패: $error");
      _showErrorDialog(context, "Logout failed.");
    }
  }

  // 에러 표시
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Login successful!'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Hello User!',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _handleLogout(context), // 로그아웃 처리
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
