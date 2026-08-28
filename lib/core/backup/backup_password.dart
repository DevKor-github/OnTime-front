import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

class BackupPassword {
  BackupPassword._(this.normalized, this.utf8Bytes);

  static const minCodePoints = 15;
  static const maxCodePoints = 128;
  static const maxUtf8Bytes = 1024;

  final String normalized;
  final List<int> utf8Bytes;

  static BackupPassword parse(String value) {
    final normalized = unorm.nfc(value);
    final codePoints = normalized.runes.length;
    final bytes = utf8.encode(normalized);
    if (codePoints < minCodePoints || codePoints > maxCodePoints) {
      throw const FormatException(
        'Backup password must contain 15 to 128 Unicode code points.',
      );
    }
    if (bytes.length > maxUtf8Bytes) {
      throw const FormatException(
        'Backup password must be no more than 1024 UTF-8 bytes.',
      );
    }
    return BackupPassword._(normalized, bytes);
  }
}
