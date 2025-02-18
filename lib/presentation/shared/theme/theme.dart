import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

ColorScheme colorScheme = const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5C79FB),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCE3FF),
    onPrimaryContainer: Color(0xFF212F6F),
    secondary: Color(0xFF00C575),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE2FFF4),
    onSecondaryContainer: Color(0xFF00480E),
    tertiary: Color(0xFFFFD956),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFFAEC),
    onTertiaryContainer: Color(0xFF604E10),
    error: Color(0xFFFF6953),
    onError: Colors.white,
    errorContainer: Color(0xFFFFEAE7),
    onErrorContainer: Color(0xFF691E14),
    surfaceDim: Color(0xFFAFB1B9),
    surface: Colors.white,
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF0F0F0),
    surfaceContainer: Color(0xFFE8E8E8),
    surfaceContainerHigh: Color(0xFFC8C8C8),
    surfaceContainerHighest: Color(0xFFB7B7B7),
    onSurface: Color(0xFF111111),
    outline: Color(0xFF777777),
    outlineVariant: Color(0xFFB7B7B7));

TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 36,
      color: colorScheme.onSurface,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      color: colorScheme.onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: colorScheme.onSurface,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      color: colorScheme.onSurface,
    ));

ThemeData themeData = ThemeData(
  colorScheme: colorScheme,
  brightness: Brightness.light,
  textTheme: textTheme,
  textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
    textStyle: WidgetStatePropertyAll(textTheme.titleSmall),
    padding: WidgetStatePropertyAll(const EdgeInsets.all(0.0)),
  )),
  elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.surfaceDim;
        } else {
          return colorScheme.primary;
        }
      },
    ),
    foregroundColor: WidgetStatePropertyAll(colorScheme.onPrimary),
    textStyle: WidgetStatePropertyAll(textTheme.titleSmall),
    maximumSize: WidgetStatePropertyAll(const Size(double.infinity, 50)),
    shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
  )),
  extensions: <ThemeExtension<dynamic>>[
    TileStyle(
      backgroundColor: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(100),
      maximumSize: const Size(double.infinity, 100),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20.0),
    ),
    DateTileThemeData(
      style: DateTileStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
      ),
    ),
  ],
);
