import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xff5C79FB),
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 4.0,
        ),
      ),
    );
  }
}
