import 'package:flutter/material.dart';

class AppButtonStyles {
  // Private constructor to prevent instantiation
  AppButtonStyles._();

  // Method to create button styles with the provided theme data
  static ButtonStyle _baseButtonStyle(TextTheme textTheme) => ButtonStyle(
        textStyle: WidgetStatePropertyAll(textTheme.titleMedium),
        maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 50)),
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
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withOpacity(0.38);
          } else {
            return colorScheme.onPrimary;
          }
        },
      ),
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
            return colorScheme.onSurface.withOpacity(0.38);
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
            return colorScheme.outlineVariant.withOpacity(0.38);
          } else {
            return colorScheme.primary;
          }
        },
      ),
    );
  }

  // Disabled style is automatically handled by setting onPressed to null
}
