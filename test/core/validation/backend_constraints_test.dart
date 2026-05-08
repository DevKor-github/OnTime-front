import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/validation/backend_constraints.dart';

void main() {
  group('PasswordPolicy', () {
    test('accepts 8-64 chars with letter number and special character', () {
      expect(PasswordPolicy.validate('Password1!'), isNull);
      expect(PasswordPolicy.validate('A1!aaaaa'), isNull);
      expect(PasswordPolicy.validate('${'A' * 62}1!'), isNull);
    });

    test('rejects passwords outside backend policy', () {
      expect(PasswordPolicy.validate('A1!aaaa'), PasswordPolicyError.tooShort);
      expect(
        PasswordPolicy.validate('${'A' * 63}1!'),
        PasswordPolicyError.tooLong,
      );
      expect(
        PasswordPolicy.validate('12345678!'),
        PasswordPolicyError.missingLetter,
      );
      expect(
        PasswordPolicy.validate('Password!'),
        PasswordPolicyError.missingNumber,
      );
      expect(
        PasswordPolicy.validate('Password1'),
        PasswordPolicyError.missingSpecialCharacter,
      );
    });
  });

  test('device ID pattern matches backend contract', () {
    expect(
      BackendConstraints.deviceIdPattern.hasMatch(
        '550e8400-e29b-41d4-a716-446655440000',
      ),
      isTrue,
    );
    expect(BackendConstraints.deviceIdPattern.hasMatch('device-1'), isFalse);
    expect(
      BackendConstraints.deviceIdPattern.hasMatch('invalid device id'),
      isFalse,
    );
  });
}
