import 'package:flutter/material.dart';

class AppButtonStyles {
  // Private constructor to prevent instantiation
  AppButtonStyles._();

  // Method to create button styles with the provided theme data
  static ButtonStyle _baseButtonStyle(TextTheme textTheme) => ButtonStyle(
        padding: WidgetStatePropertyAll(const EdgeInsets.all(16.0)),
        visualDensity: VisualDensity.standard,
        textStyle: WidgetStatePropertyAll(textTheme.titleMedium),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        elevation: const WidgetStatePropertyAll(0),
      );

  // Primary button style (colorScheme.primary)
  static ButtonStyle elevatedPrimary(
      ColorScheme colorScheme, TextTheme textTheme) {
    return _baseButtonStyle(textTheme).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.surfaceDim;
          } else {
            return colorScheme.primary;
          }
        },
      ),
      foregroundColor: WidgetStateProperty.all(colorScheme.onPrimary),
    );
  }

  // Primary container variant style (colorScheme.primaryContainer)
  static ButtonStyle elevatedSecondary(
      ColorScheme colorScheme, TextTheme textTheme) {
    return _baseButtonStyle(textTheme).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.surfaceDim;
          } else {
            return colorScheme.primaryContainer;
          }
        },
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          } else {
            return colorScheme.onPrimaryContainer;
          }
        },
      ),
    );
  }

  static ButtonStyle textPrimary(ColorScheme colorScheme, TextTheme textTheme) {
    return _baseButtonStyle(textTheme).copyWith(
      textStyle: WidgetStateProperty.all(textTheme.titleLarge),
      padding: WidgetStatePropertyAll(const EdgeInsets.all(0.0)),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.outlineVariant.withValues(alpha: 0.38);
          } else {
            return colorScheme.primary;
          }
        },
      ),
    );
  }

  // Disabled style is automatically handled by setting onPressed to null
}
