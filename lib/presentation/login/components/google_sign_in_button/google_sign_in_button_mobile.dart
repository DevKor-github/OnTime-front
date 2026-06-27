import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 358,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledForegroundColor: Colors.black,
          elevation: 1,
          shadowColor: Colors.black26,
          disabledMouseCursor: SystemMouseCursors.basic,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Color(0xFFDADCE0), width: 1),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'google_icon.svg',
              package: 'assets',
              semanticsLabel: 'Google Icon',
              fit: BoxFit.contain,
              width: 20,
              height: 20,
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Sign in with Google',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 21,
                  height: 1.4,
                  letterSpacing: 0,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
