import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EarlyLateMessageImageWidget extends StatelessWidget {
  final double screenHeight;
  final String earlylateMessage;
  final String earlylateImage;

  const EarlyLateMessageImageWidget({
    super.key,
    required this.screenHeight,
    required this.earlylateMessage,
    required this.earlylateImage,
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
        const SizedBox(height: 100),
        SvgPicture.asset(
          'characters/$earlylateImage',
          package: 'assets',
          height: screenHeight * 0.4,
        ),
      ],
    );
  }
}
