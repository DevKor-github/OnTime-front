import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_local_only_boundary.dart';

void main() {
  test('product source and release configuration contain no network client', () {
    expect(validateLocalOnlyBoundary(Directory.current), isEmpty);
  });
}
