import 'package:flutter/material.dart';

@immutable
class TileStyle extends ThemeExtension<TileStyle> {
  const TileStyle({
    this.backgroundColor,
    this.borderRadius,
    this.minimumSize,
    this.maximumSize,
    this.padding,
    this.margin,
  });

  /// the tile's background fill color.
  final Color? backgroundColor;

  final BorderRadius? borderRadius;

  /// The height of the tile.
  /// If null, the height will be determined by the child widget.
  final Size? minimumSize;

  /// The width of the tile.
  /// If null, the width will be determined by the child widget.
  final Size? maximumSize;

  /// The padding of the tile.
  final EdgeInsetsGeometry? padding;

  /// The margin of the tile.
  final EdgeInsetsGeometry? margin;
  @override
  TileStyle copyWith(
      {Color? backgroundColor,
      BorderRadius? borderRadius,
      EdgeInsetsGeometry? padding,
      EdgeInsetsGeometry? margin,
      Size? minimumSize,
      Size? maximumSize}) {
    return TileStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      minimumSize: minimumSize ?? this.minimumSize,
      maximumSize: maximumSize ?? this.maximumSize,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
    );
  }

  @override
  TileStyle lerp(TileStyle? other, double t) {
    if (other is! TileStyle) {
      return this;
    }
    return TileStyle(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      minimumSize: Size.lerp(minimumSize, other.minimumSize, t),
      maximumSize: Size.lerp(maximumSize, other.maximumSize, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      margin: EdgeInsetsGeometry.lerp(margin, other.margin, t),
    );
  }

  // Optional
  @override
  String toString() =>
      'TileStyle(backgroundColor: $backgroundColor, borderRadius: $borderRadius, minimumSize: $minimumSize, maximumSize: $maximumSize, padding: $padding, margin: $margin)';
}
