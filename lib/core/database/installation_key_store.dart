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

  Future<Uint8List?> readExisting() async {
    final encoded = await _storage.read(key: _keyName, iOptions: _iosOptions);
    if (encoded == null) return null;
    final decoded = base64Url.decode(encoded);
    if (decoded.length != _keyLength) {
      throw const FormatException('Invalid installation data key length.');
    }
    return Uint8List.fromList(decoded);
  }

  /// Only the initial-store ownership guard authorizes this product operation.
  Future<Uint8List> createVerified() async {
    final existing = await readExisting();
    if (existing != null) return existing;
    final random = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(_keyLength, (_) => random.nextInt(256)),
    );
    try {
      await _storage.write(
        key: _keyName,
        value: base64UrlEncode(key),
        iOptions: _iosOptions,
      );
    } catch (_) {
      // A failed response may still have persisted the value. Never write a
      // second key to make an uncertain first write look successful.
      final observed = await readExisting();
      if (observed == null || !_equal(key, observed)) rethrow;
      return observed;
    }
    final observed = await readExisting();
    if (observed == null || !_equal(key, observed)) {
      throw StateError('Installation key write unconfirmed');
    }
    return observed;
  }

  static bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Kept for explicit key-store fixtures. The product opener uses its ownership
  // guard and never invokes implicit creation for an existing store.
  Future<Uint8List> getOrCreate() async =>
      await readExisting() ?? await createVerified();

  Future<void> delete() =>
      _storage.delete(key: _keyName, iOptions: _iosOptions);

  /// Checks absence without creating a replacement key during recovery.
  Future<bool> exists() async =>
      await _storage.read(key: _keyName, iOptions: _iosOptions) != null;
}
