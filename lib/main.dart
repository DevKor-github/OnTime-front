import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:on_time_front/widgets/google_login_button.dart';
import 'package:on_time_front/widgets/google_login_ref.dart';
import 'package:on_time_front/widgets/kakao_login_button.dart';

void main() async {
  // 카카오톡 host 초기화
  KakaoSdk.init(
    nativeAppKey: '20830c4f7ddc6e7b5e0e8798b7a76d1d',
    javaScriptAppKey: '88dfce85357afe3bc7b7acd971fd008a',
  );

  runApp(const ProviderScope(child: MyApp()));
  WidgetsFlutterBinding.ensureInitialized();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ontime',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Ontime home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GoogleLoginButton(),
            SizedBox(
              height: 10,
            ),
            KakaoLoginButton(),
            SizedBox(
              height: 10,
            ),
            GoogleLoginRef(),
          ],
        ),
      ),
    );
  }
}
