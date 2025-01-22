import 'package:flutter/material.dart';

class PreparationDone extends StatefulWidget {
  const PreparationDone({super.key});

  @override
  State<PreparationDone> createState() => _PreparationDoneState();
}

class _PreparationDoneState extends State<PreparationDone> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(
              child: Text(
                "준비 끝! 어서 나가요!",
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Image.asset(
              'lib/images/ontime_mascot.png',
              width: 204,
              height: 269,
            ),
          ),
        ],
      ),
    );
  }
}
