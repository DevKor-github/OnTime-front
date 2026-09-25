import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:on_time_front/core/backup/backup_password.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:sodium/sodium_sumo.dart';
import 'backup_limits.dart';
import 'backup_json_reader.dart';

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

  /// Explicit memory-input compatibility adapter. Mobile picker/export paths
  /// use the streams and never join a whole container here.
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required String password,
  }) async {
    final output = BytesBuilder(copy: false);
    await for (final bytes in encryptStream(
      plaintext: Stream.value(plaintext),
      plaintextLength: plaintext.length,
      password: password,
    )) {
      output.add(bytes);
    }
    return output.takeBytes();
  }

  Future<Uint8List> decrypt({
    required Uint8List container,
    required String password,
  }) async {
    final output = BytesBuilder(copy: false);
    await for (final bytes in decryptStream(
      container: Stream.value(container),
      password: password,
    )) {
      output.add(bytes);
    }
    return output.takeBytes();
  }

  Stream<Uint8List> encryptStream({
    required Stream<List<int>> plaintext,
    required int plaintextLength,
    required String password,
    BackupBudget? budget,
  }) async* {
    budget ??= BackupBudget();
    budget.lease?.check();
    if (plaintextLength < 0 || plaintextLength > BackupLimits.plainBytes) {
      BackupLimits.exceeded('plainBytes');
    }
    final prepared = BackupPassword.parse(password);
    final sodium = await _sodiumLoader();
    final salt = sodium.randombytes.buf(16);
    final header = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'formatVersion': formatVersion,
          'suite': 'argon2id13+xchacha20poly1305-secretstream',
          'opsLimit': opsLimit,
          'memLimit': memLimit,
          'salt': base64UrlEncode(salt),
          'chunkSize': chunkSize,
        }),
      ),
    );
    SecureKey? key;
    try {
      key = await _deriveKey(sodium, prepared, salt);
      budget.lease?.check();
      final chunks = plaintextLength == 0
          ? 1
          : (plaintextLength + chunkSize - 1) ~/ chunkSize;
      final frameCount = chunks + 1; // secretstream header is the first frame.
      final prefix = BytesBuilder(copy: false)
        ..add(ascii.encode(_magic))
        ..add(_uint32(header.length))
        ..add(header)
        ..add(_uint32(frameCount));
      final prefixBytes = prefix.takeBytes();
      budget.ciphertext(prefixBytes.length);
      yield prefixBytes;
      var actualFrames = 0;
      await for (final frame in sodium.crypto.secretStream.pushEx(
        key: key,
        messageStream: _messages(plaintext, plaintextLength, header, budget),
      )) {
        if (++actualFrames > frameCount ||
            frame.message.length > _maxFrameBytes) {
          BackupLimits.invalid();
        }
        budget.ciphertext(4 + frame.message.length);
        budget.buffer(frame.message.length);
        yield _uint32(frame.message.length);
        yield frame.message;
      }
      if (actualFrames != frameCount) BackupLimits.invalid();
    } finally {
      try {
        key?.dispose();
      } finally {
        salt.fillRange(0, salt.length, 0);
      }
    }
  }

  Stream<SecretStreamPlainMessage> _messages(
    Stream<List<int>> source,
    int expected,
    Uint8List header,
    BackupBudget budget,
  ) async* {
    final iterator = StreamIterator(_chunks(source, budget));
    try {
      var has = await iterator.moveNext();
      if (!has) {
        if (expected != 0) BackupLimits.invalid();
        yield SecretStreamPlainMessage(
          Uint8List(0),
          additionalData: header,
          tag: SecretStreamMessageTag.finalPush,
        );
        return;
      }
      var seen = 0;
      while (has) {
        final current = iterator.current;
        seen += current.length;
        if (seen > expected) BackupLimits.invalid();
        // Look ahead before emitting the final tag; no tail can be hidden by a
        // crypto transformer cancelling its source after finalPush.
        has = await iterator.moveNext();
        if (!has && seen != expected) BackupLimits.invalid();
        yield SecretStreamPlainMessage(
          current,
          additionalData: header,
          tag: has
              ? SecretStreamMessageTag.message
              : SecretStreamMessageTag.finalPush,
        );
      }
    } finally {
      await iterator.cancel();
    }
  }

  Stream<Uint8List> _chunks(
    Stream<List<int>> source,
    BackupBudget budget,
  ) async* {
    var pending = Uint8List(chunkSize);
    var used = 0;
    await for (final bytes in source) {
      budget.plaintext(bytes.length);
      var offset = 0;
      while (offset < bytes.length) {
        final count = (bytes.length - offset).clamp(0, chunkSize - used);
        pending.setRange(used, used + count, bytes, offset);
        used += count;
        offset += count;
        if (used == chunkSize) {
          budget.buffer(chunkSize * 2);
          yield pending;
          pending = Uint8List(chunkSize);
          used = 0;
        }
      }
    }
    if (used != 0) yield Uint8List.sublistView(pending, 0, used);
  }

  Stream<Uint8List> decryptStream({
    required Stream<List<int>> container,
    required String password,
    BackupBudget? budget,
  }) async* {
    budget ??= BackupBudget();
    final normalizedPassword = BackupPassword.parse(password);
    final reader = _BackupStreamReader(container, budget);
    SecureKey? key;
    Uint8List? salt;
    Object? originalError;
    try {
      if (ascii.decode(await reader.read(_magic.length)) != _magic) {
        BackupLimits.invalid();
      }
      final length = await reader.uint32();
      if (length <= 0 || length > _maxHeaderBytes) BackupLimits.invalid();
      final header = await reader.read(length);
      // The envelope header is small (at most 4 KiB), but still untrusted JSON:
      // reject duplicate keys/deep nesting before KDF just like portable input.
      final headerSink = _HeaderSink();
      final headerNode = await BackupJsonReader(
        headerSink,
        budget,
      ).read(Stream.value(header));
      final metadata = headerSink.nodes[headerNode];
      if (metadata is! Map<String, dynamic>) BackupLimits.invalid();
      _validateHeader(metadata);
      salt = Uint8List.fromList(base64Url.decode(metadata['salt'] as String));
      if (salt.length != 16) BackupLimits.invalid();
      final frameCount = await reader.uint32();
      if (frameCount < 2 || frameCount > _maxFrameCount) BackupLimits.invalid();
      final sodium = await _sodiumLoader();
      key = await _deriveKey(sodium, normalizedPassword, salt);
      budget.lease?.check();
      var consumed = 0;
      var finalized = false;
      Stream<SecretStreamCipherMessage> frames() async* {
        for (var i = 0; i < frameCount; i++) {
          if (finalized) {
            throw const BackupProcessingFailure(
              BackupFailureKind.authentication,
            );
          }
          final size = await reader.uint32();
          if (size <= 0 || size > _maxFrameBytes) BackupLimits.invalid();
          final bytes = await reader.read(size);
          consumed++;
          yield SecretStreamCipherMessage(
            bytes,
            additionalData: i == 0 ? null : header,
          );
        }
      }

      try {
        await for (final message in sodium.crypto.secretStream.pullEx(
          key: key,
          cipherStream: frames(),
        )) {
          budget.plaintext(message.message.length);
          finalized = message.tag == SecretStreamMessageTag.finalPush;
          // An authenticated final must also be the declared last frame.
          // Reject here before sodium receives another frame after finalPush
          // and exposes a transformer StateError for an untrusted container.
          if (finalized && consumed != frameCount) {
            throw const BackupProcessingFailure(
              BackupFailureKind.authentication,
            );
          }
          yield message.message;
        }
      } catch (error) {
        if (error is SodiumException ||
            error is StreamClosedEarlyException ||
            error is InvalidHeaderException) {
          throw const BackupProcessingFailure(BackupFailureKind.authentication);
        }
        rethrow;
      }
      if (!finalized || consumed != frameCount) {
        throw const BackupProcessingFailure(BackupFailureKind.authentication);
      }
      await reader.requireEnd();
    } on FormatException catch (error) {
      if (error is BackupProcessingFailure) {
        originalError = error;
        rethrow;
      }
      const typed = BackupProcessingFailure(BackupFailureKind.dataInvariant);
      originalError = typed;
      throw typed;
    } catch (error) {
      originalError = error;
      rethrow;
    } finally {
      try {
        await reader.close();
      } catch (cleanup) {
        throw BackupProcessingCleanupFailure(
          originalError: originalError,
          cleanupError: cleanup,
        );
      } finally {
        try {
          key?.dispose();
        } finally {
          salt?.fillRange(0, salt.length, 0);
        }
      }
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
    if (header['formatVersion'] is! int ||
        header['formatVersion'] != formatVersion) {
      throw const BackupProcessingFailure(
        BackupFailureKind.unsupportedRepresentation,
      );
    }
    if (header['opsLimit'] is! int ||
        header['memLimit'] is! int ||
        header['chunkSize'] is! int ||
        header['suite'] != 'argon2id13+xchacha20poly1305-secretstream' ||
        header['opsLimit'] != opsLimit ||
        header['memLimit'] != memLimit ||
        header['chunkSize'] != chunkSize ||
        header['salt'] is! String) {
      throw const BackupProcessingFailure(
        BackupFailureKind.unsupportedRepresentation,
      );
    }
  }

  Uint8List _uint32(int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }
}

class _BackupStreamReader {
  _BackupStreamReader(Stream<List<int>> source, this.budget)
    : _input = StreamIterator(source);
  final StreamIterator<List<int>> _input;
  final BackupBudget budget;
  List<int> _chunk = const [];
  int _offset = 0;
  bool _done = false;

  Future<bool> _available() async {
    while (_offset == _chunk.length && !_done) {
      budget.lease?.check();
      if (!await _input.moveNext()) {
        _done = true;
        break;
      }
      _chunk = _input.current;
      _offset = 0;
      budget.ciphertext(_chunk.length);
    }
    return _offset < _chunk.length;
  }

  Future<Uint8List> read(int size) async {
    if (size < 0 || size > BackupCrypto._maxFrameBytes) BackupLimits.invalid();
    final result = Uint8List(size);
    budget.buffer(size);
    var filled = 0;
    while (filled < size) {
      if (!await _available()) {
        throw const BackupProcessingFailure(BackupFailureKind.authentication);
      }
      final count = (_chunk.length - _offset).clamp(0, size - filled);
      result.setRange(filled, filled + count, _chunk, _offset);
      _offset += count;
      filled += count;
    }
    return result;
  }

  Future<int> uint32() async =>
      ByteData.sublistView(await read(4)).getUint32(0, Endian.big);
  Future<void> requireEnd() async {
    if (await _available()) {
      throw const BackupProcessingFailure(BackupFailureKind.authentication);
    }
  }

  Future<void> close() => _input.cancel();
}

// The entire header is already bounded to 4096 bytes before this sink exists.
// This adapter must never be used for the portable payload.
class _HeaderSink implements BackupJsonSink {
  final nodes = <int, dynamic>{};
  @override
  int writeNode(int? parent, String? key, String kind, Object? scalar) {
    final dynamic value = kind == 'object'
        ? <String, dynamic>{}
        : kind == 'array'
        ? <dynamic>[]
        : scalar;
    final id = nodes.length + 1;
    if (parent != null) {
      final target = nodes[parent];
      if (target is Map<String, dynamic>) {
        if (target.containsKey(key)) BackupLimits.invalid();
        target[key!] = value;
      } else {
        (target as List).add(value);
      }
    }
    nodes[id] = value;
    return id;
  }
}
