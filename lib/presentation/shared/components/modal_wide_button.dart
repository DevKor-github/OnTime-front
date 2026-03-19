import 'package:flutter/material.dart';

enum ModalWideButtonVariant {
  neutral,
  primary,
  destructive,
}

enum ModalWideButtonLayout {
  fixed,
  full,
  flex,
}

class ModalWideButton extends StatelessWidget {
  const ModalWideButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.variant = ModalWideButtonVariant.neutral,
    this.layout = ModalWideButtonLayout.fixed,
    this.height = 43,
    this.fixedWidth = 245,
    this.textStyle,
  });

  final VoidCallback? onPressed;
  final String text;
  final ModalWideButtonVariant variant;
  final ModalWideButtonLayout layout;
  final double height;
  final double fixedWidth;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (backgroundColor, foregroundColor) = switch (variant) {
      ModalWideButtonVariant.neutral => (
          colorScheme.surfaceContainerLow,
          colorScheme.outline,
        ),
      ModalWideButtonVariant.primary => (
          colorScheme.primary,
          colorScheme.onPrimary,
        ),
      ModalWideButtonVariant.destructive => (
          colorScheme.error,
          colorScheme.onError,
        ),
    };

    final defaultTextStyle = theme.textTheme.titleSmall?.copyWith(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 1.4,
      color: foregroundColor,
    );

    final minSize = switch (layout) {
      ModalWideButtonLayout.flex => Size.zero,
      ModalWideButtonLayout.fixed => Size(fixedWidth, height),
      ModalWideButtonLayout.full => Size(double.infinity, height),
    };

    final button = SizedBox(
      width: switch (layout) {
        ModalWideButtonLayout.fixed => fixedWidth,
        ModalWideButtonLayout.full => double.infinity,
        ModalWideButtonLayout.flex => null,
      },
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(backgroundColor),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          ),
          alignment: Alignment.center,
          minimumSize: WidgetStateProperty.all(minSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle ?? defaultTextStyle,
        ),
      ),
    );

    return switch (layout) {
      ModalWideButtonLayout.flex => Expanded(child: button),
      _ => button,
    };
  }
}
