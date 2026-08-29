import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:on_time_front/core/backup/backup_password.dart';
import 'package:sodium/sodium_sumo.dart';

class BackupCrypto {
  BackupCrypto({Future<SodiumSumo> Function()? sodiumLoader})
    : _sodiumLoader = sodiumLoader ?? (() async => SodiumSumoInit.init());

  static const _magic = 'ONTIMEBK';
  static const formatVersion = 1;
  static const opsLimit = 3;
  static const memLimit = 64 * 1024 * 1024;
  static const chunkSize = 64 * 1024;
  static const _maxHeaderBytes = 4096;
  static const _maxFrameCount = 100000;
  static const _maxFrameBytes = chunkSize + 1024;
  final Future<SodiumSumo> Function() _sodiumLoader;

  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required String password,
  }) async {
    final normalizedPassword = BackupPassword.parse(password);
    final sodium = await _sodiumLoader();
    final salt = sodium.randombytes.buf(16);
    final header = utf8.encode(
      jsonEncode({
        'formatVersion': formatVersion,
        'suite': 'argon2id13+xchacha20poly1305-secretstream',
        'opsLimit': opsLimit,
        'memLimit': memLimit,
        'salt': base64UrlEncode(salt),
        'chunkSize': chunkSize,
      }),
    );
    final key = await _deriveKey(sodium, normalizedPassword, salt);
    try {
      final chunks = <Uint8List>[
        for (var offset = 0; offset < plaintext.length; offset += chunkSize)
          Uint8List.sublistView(
            plaintext,
            offset,
            (offset + chunkSize).clamp(0, plaintext.length),
          ),
      ];
      if (chunks.isEmpty) chunks.add(Uint8List(0));
      final encrypted = await sodium.crypto.secretStream
          .pushEx(
            key: key,
            messageStream: Stream.fromIterable([
              for (final (index, chunk) in chunks.indexed)
                SecretStreamPlainMessage(
                  chunk,
                  additionalData: Uint8List.fromList(header),
                  tag: index == chunks.length - 1
                      ? SecretStreamMessageTag.finalPush
                      : SecretStreamMessageTag.message,
                ),
            ]),
          )
          .toList();

      final builder = BytesBuilder(copy: false)
        ..add(ascii.encode(_magic))
        ..add(_uint32(header.length))
        ..add(header)
        ..add(_uint32(encrypted.length));
      for (final frame in encrypted) {
        builder
          ..add(_uint32(frame.message.length))
          ..add(frame.message);
      }
      return builder.takeBytes();
    } finally {
      key.dispose();
      salt.fillRange(0, salt.length, 0);
    }
  }

  Future<Uint8List> decrypt({
    required Uint8List container,
    required String password,
  }) async {
    final normalizedPassword = BackupPassword.parse(password);
    final reader = _ByteReader(container);
    if (ascii.decode(reader.read(_magic.length)) != _magic) {
      throw const FormatException('Not an OnTime backup file.');
    }
    final headerLength = reader.readUint32();
    if (headerLength <= 0 || headerLength > _maxHeaderBytes) {
      throw const FormatException('Unsafe backup header length.');
    }
    final header = reader.read(headerLength);
    final metadata = jsonDecode(utf8.decode(header));
    if (metadata is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup header.');
    }
    _validateHeader(metadata);
    final salt = Uint8List.fromList(
      base64Url.decode(metadata['salt'] as String),
    );
    if (salt.length != 16) throw const FormatException('Invalid backup salt.');

    final frameCount = reader.readUint32();
    if (frameCount < 2 || frameCount > _maxFrameCount) {
      throw const FormatException('Unsafe backup frame count.');
    }
    final frames = <Uint8List>[];
    for (var index = 0; index < frameCount; index++) {
      final length = reader.readUint32();
      if (length <= 0 || length > _maxFrameBytes) {
        throw const FormatException('Unsafe backup frame length.');
      }
      frames.add(reader.read(length));
    }
    if (!reader.isAtEnd) throw const FormatException('Unexpected backup data.');

    final sodium = await _sodiumLoader();
    final key = await _deriveKey(sodium, normalizedPassword, salt);
    try {
      final decrypted = await sodium.crypto.secretStream
          .pullEx(
            key: key,
            cipherStream: Stream.fromIterable([
              SecretStreamCipherMessage(frames.first),
              for (final frame in frames.skip(1))
                SecretStreamCipherMessage(frame, additionalData: header),
            ]),
          )
          .toList();
      return Uint8List.fromList([
        for (final message in decrypted) ...message.message,
      ]);
    } catch (_) {
      throw const FormatException('Wrong password or damaged backup file.');
    } finally {
      key.dispose();
      salt.fillRange(0, salt.length, 0);
    }
  }

  Future<SecureKey> _deriveKey(
    SodiumSumo sodium,
    BackupPassword password,
    Uint8List salt,
  ) {
    final signedPassword = Int8List.fromList(
      password.utf8Bytes.map((byte) => byte > 127 ? byte - 256 : byte).toList(),
    );
    return sodium.runIsolated((_, _) {
      return sodium.crypto.pwhash(
        outLen: sodium.crypto.secretStream.keyBytes,
        password: signedPassword,
        salt: salt,
        opsLimit: opsLimit,
        memLimit: memLimit,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
    });
  }

  void _validateHeader(Map<String, dynamic> header) {
    if (header['formatVersion'] != formatVersion) {
      throw const FormatException('Unsupported backup format version.');
    }
    if (header['suite'] != 'argon2id13+xchacha20poly1305-secretstream' ||
        header['opsLimit'] != opsLimit ||
        header['memLimit'] != memLimit ||
        header['chunkSize'] != chunkSize ||
        header['salt'] is! String) {
      throw const FormatException('Unsupported or unsafe backup crypto suite.');
    }
  }

  Uint8List _uint32(int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }
}

class _ByteReader {
  _ByteReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isAtEnd => _offset == _bytes.length;

  Uint8List read(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw const FormatException('Truncated backup file.');
    }
    final result = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return result;
  }

  int readUint32() {
    final value = ByteData.sublistView(read(4)).getUint32(0, Endian.big);
    return value;
  }
}
