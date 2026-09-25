import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'store_pair.dart';

/// Small secure-storage adapter for explicit pair slots. No implicit rotation.
final class PairKeyStore {
  PairKeyStore({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage storage;
  static const options = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static const historyKey = 'ontime_store_pair_used_v1';
  String slot(StorePair pair) => pair.isLegacy
      ? 'ontime_local_database_key_v1'
      : 'ontime_recovery_key_v1_${pair.id}';
  Future<String?> raw(StorePair pair) =>
      storage.read(key: slot(pair), iOptions: options);
  Future<Uint8List?> read(StorePair pair) async {
    final value = await raw(pair);
    if (value == null) return null;
    try {
      final bytes = base64Url.decode(value);
      if (bytes.length != 32) throw const PairAuthorityUnavailable();
      return Uint8List.fromList(bytes);
    } catch (_) {
      throw const PairAuthorityUnavailable();
    }
  }

  Future<Uint8List> create(StorePair pair) async {
    if (pair.isLegacy || await raw(pair) != null) {
      throw const PairAuthorityUnavailable();
    }
    final random = Random.secure();
    final value = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    try {
      await storage.write(key: slot(pair), value: value, iOptions: options);
    } catch (_) {
      if (await raw(pair) != value) rethrow;
    }
    if (await raw(pair) != value) throw const PairAuthorityUnavailable();
    return (await read(pair))!;
  }

  Future<void> remove(StorePair pair) async {
    await storage.delete(key: slot(pair), iOptions: options);
    if (await raw(pair) != null) throw const PairAuthorityUnavailable();
  }

  Future<bool> hasHistory() async {
    final value = await storage.read(key: historyKey, iOptions: options);
    if (value != null && value != '1') throw const PairAuthorityUnavailable();
    return value != null;
  }

  Future<void> markHistory() async {
    // Never normalize an invalid/future marker by overwriting it.
    if (await hasHistory()) return;
    try {
      await storage.write(key: historyKey, value: '1', iOptions: options);
    } catch (_) {
      if (await hasHistory()) {
        return; // Only exact read-back proves response loss.
      }
      rethrow;
    }
    if (!await hasHistory()) throw const PairAuthorityUnavailable();
  }

  Future<void> removeHistory() async {
    await storage.delete(key: historyKey, iOptions: options);
    if (await hasHistory()) throw const PairAuthorityUnavailable();
  }
}
