import 'dart:ffi';
import 'dart:io';

import 'package:sodium/sodium_sumo.dart';

Future<SodiumSumo> loadSodiumForTest() {
  final library = switch (Platform.operatingSystem) {
    'macos' => '/opt/homebrew/lib/libsodium.dylib',
    'linux' => 'libsodium.so',
    'windows' => 'libsodium.dll',
    _ => throw UnsupportedError('Unsupported unit-test platform.'),
  };
  return SodiumSumoInit.init(() => DynamicLibrary.open(library));
}
