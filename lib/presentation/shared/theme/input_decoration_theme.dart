import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class AppInputDecorationTheme {
  // Private constructor to prevent instantiation
  AppInputDecorationTheme._();

  static InputDecorationTheme create(
      ColorScheme colorScheme, TextTheme textTheme) {
    return InputDecorationTheme(
      // Content padding
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 0.0),

      // Border styling
      border: UnderlineInputBorder(
        borderSide: BorderSide(
          color: colorScheme.outline,
          width: 1.0,
        ),
      ),

      // Enabled border (normal state)
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: colorScheme.outline,
          width: 1.0,
        ),
      ),

      // Focused border (blue underline)
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 2.0,
        ),
      ),

      // Error border (red underline)
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 2.0,
        ),
      ),

      // Focused error border
      focusedErrorBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 2.0,
        ),
      ),

      // Disabled border
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: colorScheme.outline.withOpacity(0.38),
          width: 1.0,
        ),
      ),

      // Text styles
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.outlineVariant,
      ),

      floatingLabelStyle: textTheme.titleExtraSmall.copyWith(
        color: colorScheme.primary,
      ),

      hintStyle: textTheme.titleMedium?.copyWith(
        color: colorScheme.outlineVariant,
      ),

      errorStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.error,
      ),

      helperStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.outlineVariant,
      ),

      // Input text style
      suffixIconColor: colorScheme.outlineVariant,
      prefixIconColor: colorScheme.outlineVariant,

      // Floating label behavior
      floatingLabelBehavior: FloatingLabelBehavior.always,

      // Dense layout
      isDense: false,
    );
  }
}
