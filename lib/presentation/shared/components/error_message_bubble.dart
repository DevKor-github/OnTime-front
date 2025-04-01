import 'package:flutter/material.dart';

class ErrorMessageBubble extends StatelessWidget {
  const ErrorMessageBubble({
    super.key,
    required this.errorMessage,
    this.action,
    this.tailPosition = TailPosition.bottom,
    this.padding = const EdgeInsets.only(left: 72.0),
  });

  final EdgeInsets padding;

  final Widget errorMessage;
  final TextButton? action;
  final TailPosition tailPosition;

  @override
  Widget build(BuildContext context) {
    final tail = Padding(
      padding: padding,
      child: _MessageBubbleTail(
        isTop: tailPosition == TailPosition.top,
      ),
    );

    final body = DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: Theme.of(context).colorScheme.error,
            decorationColor: Theme.of(context).colorScheme.error,
          ),
      child: _MessageBubbleBody(
        errorMessage: errorMessage,
        action: action,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tailPosition == TailPosition.top ? [tail, body] : [body, tail],
    );
  }
}

/// Specifies the position of the bubble's tail (top or bottom).
///
/// Used to determine where the tail of the error message bubble is displayed.
enum TailPosition { top, bottom }

class _MessageBubbleTail extends StatelessWidget {
  const _MessageBubbleTail({required this.isTop});

  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _MessageBubbleTailPainter(
        color: colorScheme.errorContainer,
        isTop: isTop,
      ),
      child: const SizedBox(
        height: 15,
        width: 15,
      ),
    );
  }
}

class _MessageBubbleTailPainter extends CustomPainter {
  _MessageBubbleTailPainter({required this.color, required this.isTop});

  final Color color;
  final bool isTop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isTop) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close();
    }

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    DefaultTextStyle.of(context).style,
                  ),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 0),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              child: action ?? const SizedBox.shrink())
        ],
      ),
    );
  }
}
