import 'package:flutter/material.dart';

class ErrorMessageBubble extends StatelessWidget {
  const ErrorMessageBubble({super.key, required this.errorMessage});
  final String errorMessage;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 72.0),
          child: _MessageBubbleTail(),
        ),
        _MessageBubbleBody(
          errorMessage: errorMessage,
        ),
      ],
    );
  }
}

class _MessageBubbleTail extends StatelessWidget {
  const _MessageBubbleTail();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _MessageBubbleTailPainter(colorScheme.errorContainer),
      child: const SizedBox(
        height: 15,
        width: 15,
      ),
    );
  }
}

class _MessageBubbleTailPainter extends CustomPainter {
  _MessageBubbleTailPainter(this.backgroundColor);
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MessageBubbleBody extends StatelessWidget {
  const _MessageBubbleBody({
    required this.errorMessage,
  });

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 13.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.errorContainer,
      ),
      child: Text(
        errorMessage,
        style: textTheme.bodyLarge?.copyWith(
          color: colorScheme.error,
        ),
      ),
    );
  }
}
