import 'package:flutter/material.dart';

class KeyboardBackedBottomSheet extends StatelessWidget {
  const KeyboardBackedBottomSheet({
    super.key,
    required this.child,
    this.heightFactor = 0.85,
    this.backgroundColor = Colors.white,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
  });

  static const keyboardBackplateKey = Key('keyboard_backed_bottom_sheet_plate');
  static const sheetKey = Key('keyboard_backed_bottom_sheet');

  final Widget child;
  final double heightFactor;
  final Color backgroundColor;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final resolvedBorderRadius = borderRadius.resolve(
      Directionality.of(context),
    );
    final topRadius =
        resolvedBorderRadius.topLeft.y > resolvedBorderRadius.topRight.y
        ? resolvedBorderRadius.topLeft.y
        : resolvedBorderRadius.topRight.y;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            if (bottomInset > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomInset + topRadius,
                child: ColoredBox(
                  key: keyboardBackplateKey,
                  color: backgroundColor,
                ),
              ),
            AnimatedPadding(
              padding: EdgeInsets.only(bottom: bottomInset),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: FractionallySizedBox(
                heightFactor: heightFactor,
                child: Container(
                  key: sheetKey,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: borderRadius,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
