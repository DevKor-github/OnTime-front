import 'package:flutter/material.dart';

class ErrorMessageBubble extends StatelessWidget {
  const ErrorMessageBubble(
      {super.key, required this.errorMessage, this.action});
  final Widget errorMessage;
  final TextButton? action;
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
        DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: Theme.of(context).colorScheme.error,
                decorationColor: Theme.of(context).colorScheme.error,
              ),
          child: _MessageBubbleBody(
            errorMessage: errorMessage,
            action: action,
          ),
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
    required this.action,
  });

  final Widget errorMessage;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 13.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.errorContainer,
      ),
      child: Row(
        children: [
          errorMessage,
          TextButtonTheme(
              data: TextButtonThemeData(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  overlayColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  elevation: WidgetStateProperty.all(0),
                  foregroundColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.error,
                  ),
                  textStyle: WidgetStateProperty.all(
                      DefaultTextStyle.of(context).style),
                ),
              ),
              child: action ?? const SizedBox.shrink())
        ],
      ),
    );
  }
}
