import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EarlyLateMessageImageWidget extends StatelessWidget {
  final double screenHeight;
  final String earlylateMessage;

  const EarlyLateMessageImageWidget({
    super.key,
    required this.screenHeight,
    required this.earlylateMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          earlylateMessage,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        SvgPicture.asset(
          'characters/character.svg',
          package: 'assets',
          height: screenHeight * 0.25,
        ),
      ],
    );
  }
}
