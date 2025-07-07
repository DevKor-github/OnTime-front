part of 'theme.dart';

TextTheme _textTheme = TextTheme(
  headlineLarge: TextStyle(
    fontSize: 40,
    color: _colorScheme.onSurface,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.normal,
    height: 1.2,
  ),
  headlineMedium: TextStyle(
    fontSize: 34,
    color: _colorScheme.onSurface,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.normal,
    height: 1.2,
  ),
  headlineSmall: TextStyle(
    fontSize: 30,
    color: _colorScheme.onSurface,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.normal,
    height: 1.3,
  ),
  titleLarge: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: _colorScheme.onSurface,
    height: 1.4,
  ),
  titleMedium: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: _colorScheme.onSurface,
    height: 1.4,
  ),
  titleSmall: TextStyle(
    fontSize: 16,
    color: _colorScheme.onSurface,
    fontWeight: FontWeight.w500,
    height: 1.4,
  ),
  bodyLarge: TextStyle(
    fontSize: 16,
    color: _colorScheme.onSurface,
    fontWeight: FontWeight.w400,
    height: 1.4,
  ),
  bodyMedium: TextStyle(
    fontSize: 14,
    color: _colorScheme.onSurface,
    fontWeight: FontWeight.w400,
    height: 1.4,
  ),
  bodySmall: TextStyle(
    fontSize: 13,
    color: _colorScheme.onSurface,
    fontWeight: FontWeight.w400,
    height: 1.4,
  ),
);

extension CustomTextThemeExtension on TextTheme {
  TextStyle get headlineExtraSmall => TextStyle(
        fontSize: 28,
        color: _colorScheme.onSurface,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.normal,
        height: 1.3,
      );
  TextStyle get titleExtraLarge => TextStyle(
        fontSize: 24,
        color: _colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );
  TextStyle get titleExtraSmall => TextStyle(
        fontSize: 14,
        color: _colorScheme.onSurface,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  TextStyle get bodyExtraSmall => TextStyle(
        fontSize: 12,
        color: _colorScheme.onSurface,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );
}
