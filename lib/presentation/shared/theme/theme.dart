import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';
import 'package:on_time_front/presentation/shared/theme/button_styles.dart';
import 'package:on_time_front/presentation/shared/theme/input_decoration_theme.dart';

part 'text_theme.dart';
part 'color_scheme.dart';

ThemeData themeData = ThemeData(
  colorScheme: _colorScheme,
  brightness: Brightness.light,
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  hoverColor: Colors.transparent,
  splashColor: Colors.transparent,
  fontFamily: 'Pretendard',
  textTheme: _textTheme,
  textButtonTheme: TextButtonThemeData(
    style: AppButtonStyles.textPrimary(_colorScheme, _textTheme),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: AppButtonStyles.elevatedPrimary(_colorScheme, _textTheme),
  ),
  inputDecorationTheme:
      AppInputDecorationTheme.create(_colorScheme, _textTheme),
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
