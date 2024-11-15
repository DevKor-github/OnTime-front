import 'package:flutter/material.dart';
import 'package:on_time_front/shared/components/tile.dart';

ColorScheme colorScheme = const ColorScheme(
    primary: Color.fromARGB(255, 92, 121, 251),
    brightness: Brightness.light,
    error: Colors.red,
    onError: Colors.white,
    onPrimary: Color.fromARGB(255, 3, 0, 0),
    onSecondary: Colors.white,
    onSurface: Color.fromARGB(255, 0, 0, 0),
    secondary: Color.fromARGB(0xff, 0x20, 0xB7, 0x67),
    surface: Color.fromARGB(255, 247, 247, 247),
    surfaceContainer: Color.fromARGB(255, 240, 240, 240));

ThemeData themeData = ThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.light,
    textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(colorScheme.primary))),
    extensions: [
      TileStyle(
        backgroundColor: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
      )
    ]);
