part of 'theme.dart';

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
