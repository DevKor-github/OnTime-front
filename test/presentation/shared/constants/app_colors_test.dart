import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

void main() {
  test('white opacity colors keep the documented alpha ladder', () {
    expect(AppColors.white, const Color(0xFFFFFFFF));
    expect(AppColors.white90.a, closeTo(0.9, 0.001));
    expect(AppColors.white80.a, closeTo(0.8, 0.001));
    expect(AppColors.white70.a, closeTo(0.7, 0.001));
    expect(AppColors.white60.a, closeTo(0.6, 0.001));
    expect(AppColors.white50.a, closeTo(0.5, 0.001));
    expect(AppColors.white40.a, closeTo(0.4, 0.001));
    expect(AppColors.white30.a, closeTo(0.3, 0.001));
    expect(AppColors.white20.a, closeTo(0.2, 0.001));
    expect(AppColors.white10.a, closeTo(0.1, 0.001));
  });

  test('brand swatches expose stable primary shades', () {
    expect(AppColors.blue, isA<MaterialColor>());
    expect(AppColors.blue.shade500, const Color(0xFF5C79FB));
    expect(AppColors.green.shade500, const Color(0xFF00CA78));
    expect(AppColors.yellow.shade500, const Color(0xFFFFD956));
    expect(AppColors.red.shade400, const Color(0xFFFF6953));
    expect(AppColors.grey.shade500, const Color(0xFF949494));
  });

  test('social type string conversion is normalized for persistence', () {
    expect(socialTypeFromString(null), SocialType.normal);
    expect(socialTypeFromString(' GOOGLE '), SocialType.google);
    expect(socialTypeFromString('apple'), SocialType.apple);
    expect(socialTypeFromString('unknown'), SocialType.normal);

    expect(socialTypeToString(SocialType.normal), 'normal');
    expect(socialTypeToString(SocialType.google), 'google');
    expect(socialTypeToString(SocialType.apple), 'apple');
  });
}
