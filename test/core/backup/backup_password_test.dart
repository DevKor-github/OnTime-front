import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_password.dart';

void main() {
  test('normalizes canonically equivalent passwords to the same value', () {
    final composed = BackupPassword.parse('é12345678901234');
    final decomposed = BackupPassword.parse('e\u030112345678901234');

    expect(decomposed.normalized, composed.normalized);
    expect(decomposed.utf8Bytes, composed.utf8Bytes);
  });

  test('preserves case and surrounding spaces', () {
    final parsed = BackupPassword.parse('  AbCdEfGhIjKlM  ');

    expect(parsed.normalized, '  AbCdEfGhIjKlM  ');
  });

  test('rejects passwords outside the 15 to 128 code point boundary', () {
    expect(() => BackupPassword.parse('12345678901234'), throwsFormatException);
    expect(
      () => BackupPassword.parse(List.filled(129, '가').join()),
      throwsFormatException,
    );
  });
}
