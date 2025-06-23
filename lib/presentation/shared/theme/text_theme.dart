import 'package:flutter/material.dart';

class AppTextTheme {
  // Private constructor to prevent instantiation
  AppTextTheme._();

  static TextTheme create(ColorScheme colorScheme) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 40,
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.normal,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 34,
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.normal,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 30,
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.normal,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }
}

extension CustomTextThemeExtension on TextTheme {
  TextStyle get headlineExtraSmall => TextStyle(
        fontSize: 28,
        color: Colors.black, // Will be overridden by theme
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.normal,
        height: 1.3,
      );

  TextStyle get titleExtraLarge => TextStyle(
        fontSize: 24,
        color: Colors.black, // Will be overridden by theme
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  TextStyle get titleExtraSmall => TextStyle(
        fontSize: 14,
        color: Colors.black, // Will be overridden by theme
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  TextStyle get bodyExtraSmall => TextStyle(
        fontSize: 12,
        color: Colors.black, // Will be overridden by theme
        fontWeight: FontWeight.w400,
        height: 1.4,
      );
}
