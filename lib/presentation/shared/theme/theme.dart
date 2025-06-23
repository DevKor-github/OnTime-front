import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';
import 'package:on_time_front/presentation/shared/theme/button_styles.dart';
import 'package:on_time_front/presentation/shared/theme/text_theme.dart';

ColorScheme _colorScheme = ColorScheme(
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
  onSurface: AppColors.grey[950]!,
  outline: AppColors.grey.shade600,
  outlineVariant: AppColors.grey.shade400,
);

TextTheme _textTheme = AppTextTheme.create(_colorScheme);

ThemeData themeData = ThemeData(
  colorScheme: _colorScheme,
  brightness: Brightness.light,
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  fontFamily: 'Pretendard',
  textTheme: _textTheme,
  textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(_colorScheme.primary),
    textStyle: WidgetStatePropertyAll(_textTheme.titleSmall),
    padding: WidgetStatePropertyAll(const EdgeInsets.all(0.0)),
  )),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: AppButtonStyles.primary(_colorScheme, _textTheme),
  ),
  dialogTheme: DialogTheme(
    backgroundColor: _colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    titleTextStyle:
        _textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
    contentTextStyle: _textTheme.bodyMedium,
  ),
  extensions: <ThemeExtension<dynamic>>[
    TileStyle(
      backgroundColor: _colorScheme.surfaceContainerLow,
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
        textStyle: WidgetStatePropertyAll(_textTheme.bodyLarge),
      ),
    ),
  ],
);
