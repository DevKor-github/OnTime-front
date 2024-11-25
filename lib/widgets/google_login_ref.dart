import 'package:flutter/material.dart';
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleLoginRef extends StatelessWidget {
  final String _loginUrl =
      "http://ejun.kro.kr:8888/login/oauth2/authorization/google";

  final LoginPlatform _loginPlatform = LoginPlatform.none;

  const GoogleLoginRef({super.key});

  // Google OAuth2 로그인 URL 실행 메서드
  Future<void> _launchLoginUrl(BuildContext context) async {
    try {
      if (await canLaunch(_loginUrl)) {
        // 브라우저를 통해 URL 열기
        await launch(_loginUrl, forceWebView: false, enableJavaScript: true);

        print("Requesting: $_loginUrl \n");

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TestScreen(
              loginPlatform: LoginPlatform.google,
            ),
          ),
        );
      } else {
        throw 'Could not launch $_loginUrl';
      }
    } catch (error) {
      print("Error: $error");
      _showErrorDialog(context, "Network Error.");
    }
  }

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
