import 'package:flutter/material.dart';

class AppButtonStyles {
  // Private constructor to prevent instantiation
  AppButtonStyles._();

  // Method to create button styles with the provided theme data
  static ButtonStyle _baseButtonStyle(TextTheme textTheme) => ButtonStyle(
        textStyle: WidgetStatePropertyAll(textTheme.titleSmall),
        maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 50)),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        elevation: const WidgetStatePropertyAll(0),
      );

  // Primary button style (colorScheme.primary)
  static ButtonStyle primary(ColorScheme colorScheme, TextTheme textTheme) {
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
  static ButtonStyle secondary(ColorScheme colorScheme, TextTheme textTheme) {
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

  // Disabled style is automatically handled by setting onPressed to null
}
