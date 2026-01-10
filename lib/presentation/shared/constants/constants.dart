const double appBarHeight = 56.0;
const int scheduleOverlapWarningThresholdMinutes = 180;

enum PreparationStateEnum {
  yet, // 준비 전
  now, // 진행 중
  done, // 완료됨
}

enum SocialType {
  normal,
  google,
  apple,
}

SocialType socialTypeFromString(String? value) {
  if (value == null) return SocialType.normal;
  final normalized = value.trim().toLowerCase();
  switch (normalized) {
    case 'google':
      return SocialType.google;
    case 'apple':
      return SocialType.apple;
    default:
      return SocialType.normal;
  }
}

String socialTypeToString(SocialType type) {
  switch (type) {
    case SocialType.normal:
      return 'normal';
    case SocialType.google:
      return 'google';
    case SocialType.apple:
      return 'apple';
  }
}
