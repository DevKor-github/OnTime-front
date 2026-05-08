class BackendConstraints {
  const BackendConstraints._();

  static const int maxScheduleNameLength = 30;
  static const int maxLongTextLength = 1000;
  static const int maxMinuteValue = 1440;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 64;

  static final RegExp deviceIdPattern = RegExp(r'^[A-Za-z0-9._:-]{16,128}$');

  static String trimToMaxLength(String value, int maxLength) {
    final trimmedValue = value.trim();
    if (trimmedValue.length <= maxLength) {
      return trimmedValue;
    }
    return trimmedValue.substring(0, maxLength);
  }
}

enum PasswordPolicyError {
  tooShort,
  tooLong,
  missingLetter,
  missingNumber,
  missingSpecialCharacter,
}

class PasswordPolicy {
  const PasswordPolicy._();

  static final RegExp _letterPattern = RegExp(r'[A-Za-z]');
  static final RegExp _numberPattern = RegExp(r'[0-9]');
  static final RegExp _specialCharacterPattern = RegExp(
    r'''[!@#$%^&*(),.?":{}|<>\[\]\\;'/`~_+=\-]''',
  );

  static PasswordPolicyError? validate(String value) {
    if (value.length < BackendConstraints.minPasswordLength) {
      return PasswordPolicyError.tooShort;
    }
    if (value.length > BackendConstraints.maxPasswordLength) {
      return PasswordPolicyError.tooLong;
    }
    if (!_letterPattern.hasMatch(value)) {
      return PasswordPolicyError.missingLetter;
    }
    if (!_numberPattern.hasMatch(value)) {
      return PasswordPolicyError.missingNumber;
    }
    if (!_specialCharacterPattern.hasMatch(value)) {
      return PasswordPolicyError.missingSpecialCharacter;
    }
    return null;
  }

  static bool isValid(String value) => validate(value) == null;
}
