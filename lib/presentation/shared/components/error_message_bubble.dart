import 'package:flutter/material.dart';

/// A widget that displays an error message bubble with an optional action button
/// and a customizable tail position.
///
/// The `ErrorMessageBubble` widget is used to show error messages in a visually
/// distinct bubble format. It supports adding an action button for user interaction
/// (e.g., retrying an operation) and allows specifying the position of the bubble's
/// tail.
///
/// Example usage:
/// ```dart
/// ErrorMessageBubble(
///   errorMessage: const Text('An error occurred. Please try again.'),
///   action: TextButton(
///     onPressed: () {
///       // Handle retry action
///     },
///     child: const Text('Retry'),
///   ),
///   tailPosition: TailPosition.bottom,
/// )
/// ```
/// The [ErrorMessageBubble] widget is designed to show error messages in a
/// visually distinct bubble with a tail pointing to the source of the error.
/// It supports customization of the error message content, an optional action
/// button, and the position of the tail (top or bottom).
///
/// The [errorMessage] parameter is required and specifies the content of the
/// error message. The [action] parameter is optional and can be used to provide
/// a button for user interaction. The [tailPosition] parameter determines whether
/// the tail is displayed at the top or bottom of the bubble. The [padding]
/// parameter allows customization of the padding around the tail.
///
/// By default, the widget uses the app's [ThemeData] to style the text and
/// colors. The error message text adopts the `bodyLarge` style from the
/// theme, with the color set to the `error` color from the theme's
/// [ColorScheme]. The bubble background uses the `errorContainer` color
/// from the theme, ensuring consistency with the app's design system.
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
