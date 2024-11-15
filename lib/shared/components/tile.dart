import 'dart:ui';
import 'package:flutter/material.dart';

class TileStyle extends ThemeExtension<TileStyle> {
  const TileStyle({
    this.backgroundColor,
    this.borderRadius,
    this.height,
    this.width,
    this.padding,
    this.margin,
  });

  /// the tile's background fill color.
  final Color? backgroundColor;

  final BorderRadius? borderRadius;

  /// The height of the tile.
  /// If null, the height will be determined by the child widget.
  final double? height;

  /// The width of the tile.
  /// If null, the width will be determined by the child widget.
  final double? width;

  /// The padding of the tile.
  final EdgeInsetsGeometry? padding;

  /// The margin of the tile.
  final EdgeInsetsGeometry? margin;

  @override
  TileStyle copyWith(
      {Color? backgroundColor,
      BorderRadius? borderRadius,
      double? height,
      double? width,
      EdgeInsetsGeometry? padding,
      EdgeInsetsGeometry? margin}) {
    return TileStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      height: height ?? this.height,
      width: width ?? this.width,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
    );
  }

  @override
  ThemeExtension<TileStyle> lerp(
      covariant ThemeExtension<TileStyle>? other, double t) {
    if (other == null) return this;
    return TileStyle(
      backgroundColor:
          Color.lerp(backgroundColor, (other as TileStyle).backgroundColor, t)!,
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      height: lerpDouble(height, other.height, t),
      width: lerpDouble(width, other.width, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      margin: EdgeInsetsGeometry.lerp(margin, other.margin, t),
    );
  }
}

class Tile extends StatelessWidget {
  const Tile(
      {super.key,
      this.statesController,
      this.style,
      this.leading,
      this.trailing,
      required this.child});

  final WidgetStatesController? statesController;

  final TileStyle? style;

  final Widget? leading;

  final Widget child;

  final Widget? trailing;

  bool get enabled => true;
  @override
  Widget build(BuildContext context) {
    final TileStyle? widgetStyle = style;
    final TileStyle? themeStyle = Theme.of(context).extension<TileStyle>();

    Color? backgroundColor =
        widgetStyle?.backgroundColor ?? themeStyle?.backgroundColor;
    BorderRadius? borderRadius =
        widgetStyle?.borderRadius ?? themeStyle?.borderRadius;
    double? height = widgetStyle?.height ?? themeStyle?.height;
    double? width = widgetStyle?.width ?? themeStyle?.width;
    EdgeInsetsGeometry? padding = widgetStyle?.padding ?? themeStyle?.padding;
    EdgeInsetsGeometry? margin = widgetStyle?.margin ?? themeStyle?.margin;

    return Padding(
      padding: margin ?? const EdgeInsets.all(0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: backgroundColor,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(8),
          child: SizedBox(
              width: width,
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      leading ?? SizedBox.shrink(),
                      child,
                    ],
                  ),
                  trailing ?? SizedBox.shrink(),
                ],
              )),
        ),
      ),
    );
  }
}
