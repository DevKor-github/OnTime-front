import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/theme/custom_text_theme.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

ColorScheme colorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.blue,
  onPrimary: AppColors.white,
  primaryContainer: AppColors.blue.shade200,
  onPrimaryContainer: AppColors.blue.shade900,
  secondary: AppColors.green,
  onSecondary: AppColors.white,
  secondaryContainer: AppColors.green.shade100,
  onSecondaryContainer: AppColors.green.shade900,
  tertiary: AppColors.yellow,
  onTertiary: AppColors.white,
  tertiaryContainer: AppColors.yellow.shade100,
  onTertiaryContainer: AppColors.yellow.shade900,
  error: AppColors.red,
  onError: Colors.white,
  errorContainer: AppColors.red.shade50,
  onErrorContainer: AppColors.red.shade900,
  surfaceDim: AppColors.grey.shade400,
  surface: AppColors.white,
  surfaceBright: AppColors.white,
  surfaceContainerLowest: AppColors.grey.shade50,
  surfaceContainerLow: AppColors.grey.shade100,
  surfaceContainer: AppColors.grey.shade200,
  surfaceContainerHigh: AppColors.grey.shade300,
  surfaceContainerHighest: AppColors.grey.shade400,
  onSurface: AppColors.grey.shade50,
  outline: AppColors.grey.shade600,
  outlineVariant: AppColors.grey.shade400,
);

TextTheme textTheme = CustomTextTheme(
  headlineLarge: TextStyle(
    fontSize: 40,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.normal,
    height: 1.193,
  ),
  headlineMedium: TextStyle(
    fontSize: 34,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.normal,
    height: 1.21,
  ),
  headlineSmall: TextStyle(
    fontSize: 30,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.normal,
    height: 1.21,
  ),
  headlineExtraSmall: TextStyle(
    fontSize: 28,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.normal,
    height: 1.193,
  ),
  titleLarge: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: colorScheme.onSurface,
    height: 1.4,
  ),
  titleMedium: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
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
    fontSize: 12,
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w500,
    height: 1.4,
  ),
  bodyExtraLarge: TextStyle(
    fontSize: 18,
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
