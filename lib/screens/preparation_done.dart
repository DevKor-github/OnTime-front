import 'package:flutter/material.dart';

class PreparationDone extends StatefulWidget {
  const PreparationDone({super.key});

  @override
  State<PreparationDone> createState() => _PreparationDoneState();
}

class _PreparationDoneState extends State<PreparationDone> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '준비시간 끝! 어서 나가요!',
        style: TextStyle(
          fontSize: 15,
        ),
      ),
    );
  }
}
