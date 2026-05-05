import 'package:flutter/material.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Image.asset(
          'logo.png',
          package: 'assets',
          width: 167,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
