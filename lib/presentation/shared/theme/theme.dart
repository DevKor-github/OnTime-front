import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

ColorScheme colorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.blue,
  onPrimary: AppColors.white,
  primaryContainer: AppColors.blue.shade700,
  onPrimaryContainer: AppColors.blue.shade50,
  secondary: AppColors.green,
  onSecondary: AppColors.white,
  secondaryContainer: const Color(0xFFE2FFF4),
  onSecondaryContainer: const Color(0xFF00480E),
  tertiary: AppColors.yellow,
  onTertiary: AppColors.white,
  tertiaryContainer: AppColors.yellow.shade800,
  onTertiaryContainer: const Color(0xFF604E10),
  error: const Color(0xFFFF6953),
  onError: Colors.white,
  errorContainer: const Color(0xFFFFEAE7),
  onErrorContainer: const Color(0xFF691E14),
  surfaceDim: const Color(0xFFAFB1B9),
  surface: AppColors.white,
  surfaceBright: AppColors.white,
  surfaceContainerLowest: AppColors.grey[1200]!,
  surfaceContainerLow: AppColors.grey[1100]!,
  surfaceContainer: AppColors.grey[1000]!,
  surfaceContainerHigh: AppColors.grey.shade800,
  surfaceContainerHighest: AppColors.grey.shade700,
  onSurface: AppColors.grey.shade100,
  outline: AppColors.grey.shade500,
  outlineVariant: AppColors.grey.shade700,
);

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
