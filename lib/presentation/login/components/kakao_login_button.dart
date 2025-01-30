import 'dart:convert'; // For json.decode
import 'dart:io'; // For HttpHeaders and Platform
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For HTTP requests
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:on_time_front/presentation/login/screens/test_screen.dart';
import 'package:on_time_front/utils/login_platform.dart';

class KakaoLoginButton extends StatefulWidget {
  const KakaoLoginButton({super.key});

  @override
  State<KakaoLoginButton> createState() => _KakaoLoginButtonState();
}

class _KakaoLoginButtonState extends State<KakaoLoginButton> {
  LoginPlatform _loginPlatform = LoginPlatform.none; // 로그인 플랫폼
  Map<String, dynamic>? _userProfile;
  String? _accessToken;

  @override
  void initState() {
    super.initState();

    KakaoSdk.init(
      nativeAppKey: '20830c4f7ddc6e7b5e0e8798b7a76d1d',
      javaScriptAppKey: '88dfce85357afe3bc7b7acd971fd008a',
    );
  }

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      OAuthToken token;

      if (kIsWeb) {
        token = await UserApi.instance.loginWithKakaoAccount();
      } else if (Platform.isAndroid || Platform.isIOS) {
        bool isInstalled = await isKakaoTalkInstalled();
        token = isInstalled
            ? await UserApi.instance.loginWithKakaoTalk()
            : await UserApi.instance.loginWithKakaoAccount();
      } else {
        throw Exception("지원하지 않는 플랫폼");
      }

      // Access Token 저장
      _accessToken = token.accessToken;

      // 사용자 정보 요청
      final url = Uri.https('kapi.kakao.com', '/v2/user/me');
      final response = await http.get(
        url,
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${token.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        print("success");
        final rawProfileInfo = json.decode(response.body);

        // userInfo에서 필요한 데이터만 추출
        final filteredProfileInfo = {
          "id": rawProfileInfo["id"].toString(),
          "profile": {
            "nickname": rawProfileInfo["kakao_account"]["profile"]["nickname"],
            "thumbnail_image_url": rawProfileInfo["kakao_account"]["profile"]
                ["thumbnail_image_url"],
            "profile_image_url": rawProfileInfo["kakao_account"]["profile"]
                ["profile_image_url"],
            "is_default_image": rawProfileInfo["kakao_account"]["profile"]
                ["is_default_image"],
            "is_default_nickname": rawProfileInfo["kakao_account"]["profile"]
                ["is_default_nickname"],
          }
        };

        print("Filtered User Info: $filteredProfileInfo");

        final backendResponse = await http.post(
          // 백엔드 URI
          Uri.parse('http://ejun.kro.kr:8888/oauth2/kakao/registerOrLogin'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode(filteredProfileInfo),
        );

        if (backendResponse.statusCode == 200) {
          print("백엔드 처리 성공: ${backendResponse.headers}");

          // TestScreen으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TestScreen(
                loginPlatform: LoginPlatform.kakao,
              ),
            ),
          );
        } else {
          print("Backend error: ${backendResponse.statusCode}");
        }

        setState(() {
          _loginPlatform = LoginPlatform.kakao;
          _userProfile = filteredProfileInfo;
        });
      } else {
        throw Exception("프로필 정보 요청 실패: ${response.body}");
      }
    } catch (error) {
      print('카카오 로그인 실패: $error');
      _showErrorDialog("카카오 로그인 실패");
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
          child: const Text('Kakao Login'),
        ),
      ],
    );
  }
}
