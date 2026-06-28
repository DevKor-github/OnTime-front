import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserRepository exposes app-owned authentication contract types', () {
    final source = File(
      'lib/domain/repositories/user_repository.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(contains("package:google_sign_in/google_sign_in.dart")),
    );
    expect(source, isNot(matches(RegExp(r'\bGoogleSignIn\w*'))));
  });
}
