import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_local_only_boundary.dart';

void main() {
  test(
    'product source and release configuration contain no network client',
    () {
      expect(validateLocalOnlyBoundary(Directory.current), isEmpty);
    },
  );

  test('iOS remote notification hooks violate the local-only boundary', () {
    final root = Directory.systemTemp.createTempSync(
      'ontime_local_only_boundary_',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    Directory('${root.path}/lib').createSync(recursive: true);
    File(
      '${root.path}/pubspec.yaml',
    ).writeAsStringSync('name: local_only_fixture\ndependencies:\n');
    final manifest = File(
      '${root.path}/android/app/src/main/AndroidManifest.xml',
    );
    manifest.parent.createSync(recursive: true);
    manifest.writeAsStringSync('<manifest />');
    final appDelegate = File('${root.path}/ios/Runner/AppDelegate.swift');
    appDelegate.parent.createSync(recursive: true);
    appDelegate.writeAsStringSync(
      'Messaging.messaging().apnsToken = deviceToken',
    );

    expect(
      validateLocalOnlyBoundary(root),
      contains(
        'ios/Runner/AppDelegate.swift contains a removed remote notification hook',
      ),
    );
  });

  test('web remote bootstrap resources violate the local-only boundary', () {
    final root = Directory.systemTemp.createTempSync(
      'ontime_web_local_only_boundary_',
    );
    addTearDown(() => root.deleteSync(recursive: true));

    Directory('${root.path}/lib').createSync(recursive: true);
    File(
      '${root.path}/pubspec.yaml',
    ).writeAsStringSync('name: local_only_fixture\ndependencies:\n');
    final manifest = File(
      '${root.path}/android/app/src/main/AndroidManifest.xml',
    );
    manifest.parent.createSync(recursive: true);
    manifest.writeAsStringSync('<manifest />');
    final webIndex = File('${root.path}/web/index.html');
    webIndex.parent.createSync(recursive: true);
    webIndex.writeAsStringSync(
      '<script src="https://accounts.example.test/client.js"></script>',
    );

    expect(
      validateLocalOnlyBoundary(root),
      contains('web/index.html contains remote runtime marker src="https://'),
    );
  });
}
