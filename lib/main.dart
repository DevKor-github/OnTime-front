import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';
import 'package:on_time_front/presentation/app/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(App());
}

class SignUp extends StatelessWidget {
  SignUp({Key? key}) : super(key: key);

  final AuthenticationRepository _authenticationRepository =
      getIt.get<AuthenticationRepository>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _authenticationRepository.signInWithGoogle();
            context.go('/home');
          },
          child: const Text('Hello, World!'),
        ),
      ),
    );
  }
}
