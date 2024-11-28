import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uni_links/uni_links.dart'; // 리다이렉트 처리
import 'package:on_time_front/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleLoginRef extends StatefulWidget {
  const GoogleLoginRef({super.key});

  @override
  _GoogleLoginRefState createState() => _GoogleLoginRefState();
}

class _GoogleLoginRefState extends State<GoogleLoginRef> {
  final String _loginUrl =
      "http://ejun.kro.kr:8888/oauth2/authorization/google";

  @override
  void initState() {
    super.initState();
    _listenForRedirect(); // 리다이렉트 처리 시작
  }

  Future<void> _launchLoginUrl(BuildContext context) async {
    try {
      if (await canLaunch(_loginUrl)) {
        // 브라우저를 통해 URL 열기
        await launch(_loginUrl, forceWebView: false, enableJavaScript: true);
        print("Requesting: $_loginUrl");
      } else {
        throw 'Could not launch $_loginUrl';
      }
    } catch (error) {
      print("Error: $error");
      _showErrorDialog(context, "Network Error.");
    }
  }

  /// 리다이렉트 URL 처리 (Authorization Code 추출)
  Future<void> _listenForRedirect() async {
    try {
      final initialLink = await getInitialLink(); // 앱 시작 시 링크 감지
      if (initialLink != null) {
        _handleRedirect(Uri.parse(initialLink));
      }

      // 리다이렉트 URL을 지속적으로 감지
      uriLinkStream.listen((Uri? link) {
        if (link != null) {
          _handleRedirect(link);
        }
      });
    } catch (error) {
      print("Error in redirect listener: $error");
    }
  }

  /// 리다이렉트 처리
  Future<void> _handleRedirect(Uri link) async {
    try {
      final code = link.queryParameters['code']; // Authorization Code 추출
      if (code != null) {
        print("Authorization Code: $code");
        await _exchangeCodeForToken(code); // 서버로 코드 전송 후 토큰 요청
      } else {
        print("Authorization code not found in URL.");
      }
    } catch (error) {
      print("Error handling redirect: $error");
    }
  }

  /// 서버에 Authorization Code 전송 -> 토큰 요청
  Future<void> _exchangeCodeForToken(String code) async {
    final url = "http://ejun.kro.kr:8888/api/auth/token"; // 토큰 엔드포인트
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode({
          "grantType": "authorization_code",
          "code": code, // 리다이렉트에서 받은 Authorization Code
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data["accessToken"];
        final refreshToken = data["refreshToken"];

        if (accessToken != null && refreshToken != null) {
          print("Access Token: $accessToken");
          print("Refresh Token: $refreshToken");

          // 로그인 성공 -> 다음 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TestScreen(
                loginPlatform: LoginPlatform.google,
              ),
            ),
          );
        } else {
          throw Exception("Tokens not found in response.");
        }
      } else {
        print("Failed to exchange code: ${response.body}");
        _showErrorDialog(context, "Failed to exchange authorization code.");
      }
    } catch (error) {
      print("Error while exchanging code: $error");
      _showErrorDialog(context, "Error occurred during token exchange.");
    }
  }

  /// 에러 표시
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
