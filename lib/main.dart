import 'package:flutter/material.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(Test());
}

class Test extends StatelessWidget {
  Test({Key? key}) : super(key: key);

  final AuthenticationRepository _authenticationRepository =
      getIt.get<AuthenticationRepository>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              _authenticationRepository.signInWithGoogle();
            },
            child: const Text('Hello, World!'),
          ),
        ),
      ),
    );
  }
}
