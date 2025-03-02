import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color white = Color(0xFFFFFFFF);

  /// White with 90% opacity.
  ///
  /// This is a color commonly used for headings in dark themes.
  ///
  /// See also:
  ///
  ///  * [Typography.white], which uses this color for its text styles.
  ///  * [Theme.of], which allows you to select colors from the current theme
  ///    rather than hard-coding colors in your build methods.
  ///  * [white], [white80], [white70], [white60], [white50], [white40],
  ///    [white30], which are variants on this color but with different
  ///    opacities.
  static final Color white90 = white.withValues(alpha: 0.9);

  /// White with 80% opacity.
  ///
  /// See also:
  ///
  ///  * [Theme.of], which allows you to select colors from the current theme
  ///    rather than hard-coding colors in your build methods.
  ///  * [white], [white70], [white60], [white50], [white40], [white30], which
  ///    are variants on this color but with different opacities.
  static final Color white80 = white.withValues(alpha: 0.8);

  /// White with 70% opacity.
  ///
  /// See also:
  ///
  ///  * [Theme.of], which allows you to select colors from the current theme
  ///    rather than hard-coding colors in your build methods.
  ///  * [white], [white60], [white50], [white40], [white30], [white20], which
  ///    are variants on this color but with different opacities.
  static final Color white70 = white.withValues(alpha: 0.7);

  /// White with 60% opacity.
  ///
  /// See also:
  ///
  ///  * [Theme.of], which allows you to select colors from the current theme
  ///    rather than hard-coding colors in your build methods.
  ///  * [white], [white50], [white40], [white30], [white20],
  ///    [white10], which are variants on this color but with different
  ///    opacities.
  static final Color white60 = white.withValues(alpha: 0.6);

  /// White with 50% opacity.
  ///
  /// See also:
  ///
  ///  * [Theme.of], which allows you to select colors from the current theme
  ///    rather than hard-coding colors in your build methods.
  ///  * [white], [white40], [white30], [white20], [white10],
  ///    which are variants on this color but with different
  ///    opacities.
  static final Color white50 = white.withValues(alpha: 0.5);

  /// White with 40% opacity.
  ///
  /// See also:
  ///   * [Theme.of], which allows you to select colors from the current theme
  ///     rather than hard-coding colors in your build methods.
  ///   * [white], [white30], [white20], [white10], which are variants on this
  ///     color but with different opacities.
  static final Color white40 = white.withValues(alpha: 0.4);

  /// White with 30% opacity.
  ///
  /// See also:
  ///  * [Theme.of], which allows you to select colors from the current theme
  ///   rather than hard-coding colors in your build methods.
  /// * [white], [white20], [white10], which are variants on this color but
  ///  with different opacities.
  static final Color white30 = white.withValues(alpha: 0.3);

  /// White with 20% opacity.
  ///
  /// See also:
  /// * [Theme.of], which allows you to select colors from the current theme
  ///  rather than hard-coding colors in your build methods.
  /// * [white], [white10], which are variants on this color but with different
  /// opacities.

  static final Color white20 = white.withValues(alpha: 0.2);

  /// White with 10% opacity.
  ///
  /// See also:
  /// * [Theme.of], which allows you to select colors from the current theme
  /// rather than hard-coding colors in your build methods.
  /// * [white], which is a variant on this color but with a different opacity.
  static final Color white10 = white.withValues(alpha: 0.1);

  /// The blue primary color and swatch.
  /// {@tool snippet}
  ///
  /// ```dart
  /// Icon(
  ///   Icons.widgets,
  ///   color: AppColors.blue[40],
  /// )
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [Theme.of], which allows you to select colors from the current theme
  ///    rather than hard-coding colors in your build methods.
  static const MaterialColor blue = MaterialColor(
    _bluePrimaryValue,
    <int, Color>{
      100: Color(0xFFF3F5FF),
      200: Color(0xFFDCE3FF),
      300: Color(0xFFB5C2FF),
      400: Color(0xFF839AFF),
      500: Color(_bluePrimaryValue),
      600: Color(0xFF4F69DF),
      700: Color(0xFF3D54BC),
      800: Color(0xFF2E4092),
      900: Color(0xFF212F6F),
    },
  );
  static const int _bluePrimaryValue = 0xFF5C79FB;

  /// The green primary color and swatch.
  /// {@tool snippet}
  /// ```dart
  /// Icon(
  ///   Icons.widgets,
  ///   color: AppColors.green[40],
  /// )
  /// ```
  /// {@end-tool}
  /// See also:
  /// * [Theme.of], which allows you to select colors from the current theme
  /// rather than hard-coding colors in your build methods.
  static const MaterialColor green = MaterialColor(
    _greenPrimaryValue,
    <int, Color>{
      100: Color(0xFFE2FFF4),
      200: Color(0xFF7EFFCC),
      300: Color(0xFF50F6B4),
      400: Color(0xFF2EE49A),
      500: Color(_greenPrimaryValue),
      600: Color(0xFF00B15F),
      700: Color(0xFF0A9846),
      800: Color(0xFF007A28),
      900: Color(0xFF006614),
    },
  );
  static const int _greenPrimaryValue = 0xFF00CA78;

  /// The yellow primary color and swatch.
  /// {@tool snippet}
  /// ```dart
  /// Icon(
  ///   Icons.widgets,
  ///   color: AppColors.yellow[40],
  /// )
  /// ```
  /// {@end-tool}
  /// See also:
  /// * [Theme.of], which allows you to select colors from the current theme
  /// rather than hard-coding colors in your build methods.

  static const MaterialColor yellow = MaterialColor(
    _yellowPrimaryValue,
    <int, Color>{
      100: Color(0xFFFFF6DB),
      200: Color(0xFFFFF2C8),
      300: Color(0xFFFFEDAD),
      400: Color(0xFFFFE384),
      500: Color(_yellowPrimaryValue),
      600: Color(0xFFE9C54B),
      700: Color(0xFFCDAE44),
      800: Color(0xFFAA8F31),
      900: Color(0xFF826D24),
    },
  );
  static const int _yellowPrimaryValue = 0xFFFFD956;

  /// The red primary color and swatch.
  ///
  /// {@tool snippet}
  /// ```dart
  /// Icon(
  ///   Icons.widgets,
  ///   color: AppColors.red[40],
  /// )
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  /// * [Theme.of], which allows you to select colors from the current theme
  /// rather than hard-coding colors in your build methods.

  static const MaterialColor red = MaterialColor(
    _redPrimaryValue,
    <int, Color>{
      50: Color(0xFFFFEAE7),
      100: Color(0xFFFECBC0),
      200: Color(0xFFFEA899),
      300: Color(0xFFFE8671),
      400: Color(_redPrimaryValue),
      500: Color(0xFFFF4E39),
      600: Color(0xFFF54834),
      700: Color(0xFFE6412F),
      800: Color(0xFFD83B2B),
      900: Color(0xFFBF2E22),
    },
  );
  static const int _redPrimaryValue = 0xFFFF6953;

  /// The grey primary color and swatch.
  /// {@tool snippet}
  /// ```dart
  /// Icon(
  ///  Icons.widgets,
  ///  color: AppColors.grey[40],
  /// )
  /// ```
  /// {@end-tool}
  /// See also:
  /// * [Theme.of], which allows you to select colors from the current theme
  /// rather than hard-coding colors in your build methods.

  static const MaterialColor grey = MaterialColor(
    _greyPrimaryValue,
    <int, Color>{
      50: Color(0xFFF6F6F6),
      100: Color(0xFFF0F0F0),
      200: Color(0xFFE8E8E8),
      250: Color(0xFFDFDFDF),
      300: Color(0xFFC8C8C8),
      400: Color(0xFFB7B7B7),
      500: Color(_greyPrimaryValue),
      600: Color(0xFF777777),
      700: Color(0xFF545454),
      800: Color(0xFF383838),
      900: Color(0xFF2A2A2A),
      950: Color(0xFF111111),
    },
  );
  static const int _greyPrimaryValue = 0xFF949494;
}
