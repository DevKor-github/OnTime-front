import 'dart:io';

const _forbiddenImports = <String>[
  'package:dio/',
  'package:http/',
  'package:firebase_',
  'package:google_sign_in/',
  'package:flutter_appauth/',
  'package:sign_in_with_apple/',
];

List<String> validateLocalOnlyBoundary(Directory root) {
  final failures = <String>[];
  final lib = Directory('${root.path}/lib');
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    for (final import in _forbiddenImports) {
      if (content.contains(import)) {
        failures.add('${_relative(root, entity)} imports $import');
      }
    }
    if (RegExp(r'''['"]https?://''').hasMatch(content)) {
      failures.add('${_relative(root, entity)} embeds a network URL');
    }
  }

  final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
  for (final dependency in const [
    'dio',
    'http',
    'firebase_core',
    'firebase_messaging',
    'firebase_analytics',
    'google_sign_in',
    'flutter_appauth',
    'sign_in_with_apple',
  ]) {
    if (RegExp('^  $dependency:', multiLine: true).hasMatch(pubspec)) {
      failures.add('pubspec.yaml declares $dependency');
    }
  }

  final mainManifest = File(
    '${root.path}/android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  if (mainManifest.contains('android.permission.INTERNET')) {
    failures.add('Android product manifest requests INTERNET');
  }

  for (final path in const [
    'android/app/build.gradle',
    'android/settings.gradle',
    'ios/Runner/AppDelegate.swift',
    'ios/Runner/Info.plist',
    'ios/Runner.xcodeproj/project.pbxproj',
  ]) {
    final file = File('${root.path}/$path');
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync().toLowerCase();
    if (content.contains('firebase') || content.contains('google-services')) {
      failures.add('$path contains a removed remote SDK configuration');
    }
  }

  return failures;
}

String _relative(Directory root, File file) =>
    file.path.substring(root.path.length + 1);

void main() {
  final failures = validateLocalOnlyBoundary(Directory.current);
  if (failures.isEmpty) {
    stdout.writeln('Local-only product boundary verified.');
    return;
  }
  for (final failure in failures) {
    stderr.writeln(failure);
  }
  exitCode = 1;
}
