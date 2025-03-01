import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Custom TextTheme with an additional titleTiny field
class CustomTextTheme extends TextTheme {
  final TextStyle? titleExtraSmall;
  final TextStyle? bodyExtraSmall;
  final TextStyle? bodyExtraLarge;
  final TextStyle? headlineExtraSmall;

  const CustomTextTheme({
    this.titleExtraSmall,
    this.bodyExtraSmall,
    this.bodyExtraLarge,
    this.headlineExtraSmall,
    super.displayLarge,
    super.displayMedium,
    super.displaySmall,
    super.headlineLarge,
    super.headlineMedium,
    super.headlineSmall,
    super.titleLarge,
    super.titleMedium,
    super.titleSmall,
    super.bodyLarge,
    super.bodyMedium,
    super.bodySmall,
    super.labelLarge,
    super.labelMedium,
    super.labelSmall,
  });

  /// Overrides copyWith
  @override
  CustomTextTheme copyWith({
    TextStyle? titleTiny,
    TextStyle? bodyTiny,
    TextStyle? bodyExtraLarge,
    TextStyle? headlineTiny,
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
  }) {
    return CustomTextTheme(
      titleExtraSmall: titleTiny ?? this.titleExtraSmall,
      bodyExtraSmall: bodyTiny ?? this.bodyExtraSmall,
      bodyExtraLarge: bodyExtraLarge ?? this.bodyExtraLarge,
      headlineExtraSmall: headlineTiny ?? this.headlineExtraSmall,
      displayLarge: displayLarge ?? this.displayLarge,
      displayMedium: displayMedium ?? this.displayMedium,
      displaySmall: displaySmall ?? this.displaySmall,
      headlineLarge: headlineLarge ?? this.headlineLarge,
      headlineMedium: headlineMedium ?? this.headlineMedium,
      headlineSmall: headlineSmall ?? this.headlineSmall,
      titleLarge: titleLarge ?? this.titleLarge,
      titleMedium: titleMedium ?? this.titleMedium,
      titleSmall: titleSmall ?? this.titleSmall,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      labelLarge: labelLarge ?? this.labelLarge,
      labelMedium: labelMedium ?? this.labelMedium,
      labelSmall: labelSmall ?? this.labelSmall,
    );
  }

  /// Overrides merge
  @override
  CustomTextTheme merge(TextTheme? other) {
    if (other == null) return this;
    return copyWith(
      displayLarge:
          displayLarge?.merge(other.displayLarge) ?? other.displayLarge,
      displayMedium:
          displayMedium?.merge(other.displayMedium) ?? other.displayMedium,
      displaySmall:
          displaySmall?.merge(other.displaySmall) ?? other.displaySmall,
      headlineLarge:
          headlineLarge?.merge(other.headlineLarge) ?? other.headlineLarge,
      headlineMedium:
          headlineMedium?.merge(other.headlineMedium) ?? other.headlineMedium,
      headlineSmall:
          headlineSmall?.merge(other.headlineSmall) ?? other.headlineSmall,
      titleLarge: titleLarge?.merge(other.titleLarge) ?? other.titleLarge,
      titleMedium: titleMedium?.merge(other.titleMedium) ?? other.titleMedium,
      titleSmall: titleSmall?.merge(other.titleSmall) ?? other.titleSmall,
      titleTiny:
          titleExtraSmall?.merge((other as CustomTextTheme).titleExtraSmall) ??
              (other as CustomTextTheme).titleExtraSmall,
      bodyTiny:
          bodyExtraSmall?.merge((other as CustomTextTheme).bodyExtraSmall) ??
              (other as CustomTextTheme).bodyExtraSmall,
      bodyExtraLarge:
          bodyExtraLarge?.merge((other as CustomTextTheme).bodyExtraLarge) ??
              (other as CustomTextTheme).bodyExtraLarge,
      headlineTiny: headlineExtraSmall
              ?.merge((other as CustomTextTheme).headlineExtraSmall) ??
          (other as CustomTextTheme).headlineExtraSmall,
      bodyLarge: bodyLarge?.merge(other.bodyLarge) ?? other.bodyLarge,
      bodyMedium: bodyMedium?.merge(other.bodyMedium) ?? other.bodyMedium,
      bodySmall: bodySmall?.merge(other.bodySmall) ?? other.bodySmall,
      labelLarge: labelLarge?.merge(other.labelLarge) ?? other.labelLarge,
      labelMedium: labelMedium?.merge(other.labelMedium) ?? other.labelMedium,
      labelSmall: labelSmall?.merge(other.labelSmall) ?? other.labelSmall,
    );
  }

  /// Overrides apply
  @override
  CustomTextTheme apply({
    Color? bodyColor,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    Color? displayColor,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    double fontSizeDelta = 0.0,
    double fontSizeFactor = 1.0,
    String? package,
  }) {
    return CustomTextTheme(
      displayLarge: displayLarge?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      displayMedium: displayMedium?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      displaySmall: displaySmall?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      headlineLarge: headlineLarge?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      headlineMedium: headlineMedium?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      headlineSmall: headlineSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      headlineExtraSmall: headlineExtraSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      titleLarge: titleLarge?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      titleMedium: titleMedium?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      titleSmall: titleSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      titleExtraSmall: titleExtraSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      bodyExtraSmall: bodyExtraSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      bodyExtraLarge: bodyExtraLarge?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      bodyLarge: bodyLarge?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      bodyMedium: bodyMedium?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      bodySmall: bodySmall?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      labelLarge: labelLarge?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      labelMedium: labelMedium?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      labelSmall: labelSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
    );
  }

  static CustomTextTheme lerp(
      CustomTextTheme? a, CustomTextTheme? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return CustomTextTheme(
      displayLarge: TextStyle.lerp(a?.displayLarge, b?.displayLarge, t),
      displayMedium: TextStyle.lerp(a?.displayMedium, b?.displayMedium, t),
      displaySmall: TextStyle.lerp(a?.displaySmall, b?.displaySmall, t),
      headlineLarge: TextStyle.lerp(a?.headlineLarge, b?.headlineLarge, t),
      headlineMedium: TextStyle.lerp(a?.headlineMedium, b?.headlineMedium, t),
      headlineSmall: TextStyle.lerp(a?.headlineSmall, b?.headlineSmall, t),
      headlineExtraSmall:
          TextStyle.lerp(a?.headlineExtraSmall, b?.headlineExtraSmall, t),
      titleLarge: TextStyle.lerp(a?.titleLarge, b?.titleLarge, t),
      titleMedium: TextStyle.lerp(a?.titleMedium, b?.titleMedium, t),
      titleSmall: TextStyle.lerp(a?.titleSmall, b?.titleSmall, t),
      titleExtraSmall:
          TextStyle.lerp(a?.titleExtraSmall, b?.titleExtraSmall, t),
      bodyExtraSmall: TextStyle.lerp(a?.bodyExtraSmall, b?.bodyExtraSmall, t),
      bodyExtraLarge: TextStyle.lerp(a?.bodyExtraLarge, b?.bodyExtraLarge, t),
      bodyLarge: TextStyle.lerp(a?.bodyLarge, b?.bodyLarge, t),
      bodyMedium: TextStyle.lerp(a?.bodyMedium, b?.bodyMedium, t),
      bodySmall: TextStyle.lerp(a?.bodySmall, b?.bodySmall, t),
      labelLarge: TextStyle.lerp(a?.labelLarge, b?.labelLarge, t),
      labelMedium: TextStyle.lerp(a?.labelMedium, b?.labelMedium, t),
      labelSmall: TextStyle.lerp(a?.labelSmall, b?.labelSmall, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CustomTextTheme &&
        displayLarge == other.displayLarge &&
        displayMedium == other.displayMedium &&
        displaySmall == other.displaySmall &&
        headlineLarge == other.headlineLarge &&
        headlineMedium == other.headlineMedium &&
        headlineSmall == other.headlineSmall &&
        headlineExtraSmall == other.headlineExtraSmall &&
        titleLarge == other.titleLarge &&
        titleMedium == other.titleMedium &&
        titleSmall == other.titleSmall &&
        titleExtraSmall == other.titleExtraSmall &&
        bodyExtraSmall == other.bodyExtraSmall &&
        bodyExtraLarge == other.bodyExtraLarge &&
        bodyLarge == other.bodyLarge &&
        bodyMedium == other.bodyMedium &&
        bodySmall == other.bodySmall &&
        labelLarge == other.labelLarge &&
        labelMedium == other.labelMedium &&
        labelSmall == other.labelSmall;
  }

  @override
  int get hashCode => Object.hash(
        displayLarge,
        displayMedium,
        displaySmall,
        headlineLarge,
        headlineMedium,
        headlineSmall,
        headlineExtraSmall,
        titleLarge,
        titleMedium,
        titleSmall,
        titleExtraSmall,
        bodyExtraSmall,
        bodyExtraLarge,
        bodyLarge,
        bodyMedium,
        bodySmall,
        labelLarge,
        labelMedium,
        labelSmall,
      );

  /// Overrides debugFillProperties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<TextStyle?>('titleTiny', titleExtraSmall));
    properties.add(DiagnosticsProperty<TextStyle?>('bodyTiny', bodyExtraSmall));
    properties
        .add(DiagnosticsProperty<TextStyle?>('bodyExtraLarge', bodyExtraLarge));
    properties.add(
        DiagnosticsProperty<TextStyle?>('headlineTiny', headlineExtraSmall));
  }
}

extension CustomTextThemeExtension on TextTheme {
  CustomTextTheme get custom {
    return this is CustomTextTheme
        ? this as CustomTextTheme
        : CustomTextTheme(
            displayLarge: displayLarge,
            displayMedium: displayMedium,
            displaySmall: displaySmall,
            headlineLarge: headlineLarge,
            headlineMedium: headlineMedium,
            headlineSmall: headlineSmall,
            titleLarge: titleLarge,
            titleMedium: titleMedium,
            titleSmall: titleSmall,
            bodyLarge: bodyLarge,
            bodyMedium: bodyMedium,
            bodySmall: bodySmall,
            labelLarge: labelLarge,
            labelMedium: labelMedium,
            labelSmall: labelSmall,
          );
  }
}
