import 'package:flutter/material.dart';

class DialogStoryBackdrop extends StatelessWidget {
  const DialogStoryBackdrop({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(child: child),
    );
  }
}

class DialogResultText extends StatelessWidget {
  const DialogResultText({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }
}
