import 'package:flutter/material.dart' hide IconAlignment;

class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 358,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'appleid_button.png',
            package: 'assets',
            width: 358,
            height: 54,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
