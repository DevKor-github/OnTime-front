import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';
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

TextTheme textTheme = CustomTextTheme(
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
  headlineExtraSmall: TextStyle(
    fontSize: 28,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.normal,
    height: 1.3,
  ),
  titleExtraLarge: TextStyle(
    fontSize: 24,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w600,
    height: 1.4,
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
  titleExtraSmall: TextStyle(
    fontSize: 14,
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
  bodyExtraSmall: TextStyle(
    fontSize: 12,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w400,
    height: 1.4,
  ),
);

ThemeData themeData = ThemeData(
  colorScheme: colorScheme,
  brightness: Brightness.light,
  fontFamily: 'Pretendard',
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
      padding: const EdgeInsets.all(16.0),
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
