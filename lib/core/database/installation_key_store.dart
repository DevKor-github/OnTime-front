import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class InstallationKeyStore {
  InstallationKeyStore({@ignoreParam FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'ontime_local_database_key_v1';
  static const _keyLength = 32;
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;

  Future<Uint8List> getOrCreate() async {
    final encoded = await _storage.read(key: _keyName, iOptions: _iosOptions);
    if (encoded != null) {
      final decoded = base64Url.decode(encoded);
      if (decoded.length != _keyLength) {
        throw const FormatException('Invalid installation data key length.');
      }
      return Uint8List.fromList(decoded);
    }

    final random = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(_keyLength, (_) => random.nextInt(256)),
    );
    await _storage.write(
      key: _keyName,
      value: base64UrlEncode(key),
      iOptions: _iosOptions,
    );
    return key;
  }

  Future<void> delete() => _storage.delete(
    key: _keyName,
    iOptions: _iosOptions,
  );
}
