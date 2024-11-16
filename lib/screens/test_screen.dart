import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:on_time_front/main.dart';
import 'package:on_time_front/utils/login_platform.dart';

class TestScreen extends StatelessWidget {
  final LoginPlatform loginPlatform; // 로그인 플랫폼

  const TestScreen({super.key, required this.loginPlatform});

  // 로그아웃 처리
  Future<void> _handleLogout(BuildContext context) async {
    try {
      // 로그인 플랫폼에 따라 로그아웃 처리
      if (loginPlatform == LoginPlatform.google) {
        // Google 로그아웃 처리
        await GoogleSignIn().signOut();
        print("Google 로그아웃 성공");
      } else if (loginPlatform == LoginPlatform.kakao) {
        // Kakao 로그아웃 처리
        await UserApi.instance.logout();
        print("Kakao 로그아웃 성공");
      }

      // 로그아웃 후 상태 초기화
      // 여기에 서버와의 세션을 끊고, 앱에서 사용자 상태를 초기화할 필요가 있을 수 있음
      // 예를 들어, 로그인 상태를 초기화하는 로직 추가 가능

      // 로그아웃 후 MyApp으로 이동
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MyApp()), // MyApp으로 이동
        (route) => false, // 이전 모든 화면 제거
      );
    } catch (error) {
      print("로그아웃 실패: $error");
      _showErrorDialog(context, "로그아웃에 실패했습니다. 다시 시도해주세요.");
    }
  }

  // 에러 다이얼로그 표시
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("오류"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("확인"),
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
