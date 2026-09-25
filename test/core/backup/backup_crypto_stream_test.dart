import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import '../../helpers/sodium_test_loader.dart';

const password = 'portable stream backup';

class _UnreadableBytes extends ListBase<int> {
  _UnreadableBytes(this.length);
  @override
  int length;
  @override
  int operator [](int index) =>
      throw StateError('must reject before payload read');
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('immutable');
}

Future<Uint8List> collect(Stream<List<int>> stream) async {
  final out = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    out.add(chunk);
  }
  return out.takeBytes();
}

List<Uint8List> frames(Uint8List data) {
  final header = ByteData.sublistView(data, 8, 12).getUint32(0);
  var at = 12 + header;
  final count = ByteData.sublistView(data, at, at + 4).getUint32(0);
  at += 4;
  final result = <Uint8List>[];
  for (var i = 0; i < count; i++) {
    final len = ByteData.sublistView(data, at, at + 4).getUint32(0);
    at += 4;
    result.add(Uint8List.sublistView(data, at, at + len));
    at += len;
  }
  return result;
}

Uint8List withFrames(Uint8List data, List<Uint8List> frames) {
  final header = ByteData.sublistView(data, 8, 12).getUint32(0);
  final result = BytesBuilder(copy: false)
    ..add(Uint8List.sublistView(data, 0, 12 + header));
  void number(int n) =>
      result.add((ByteData(4)..setUint32(0, n)).buffer.asUint8List());
  number(frames.length);
  for (final frame in frames) {
    number(frame.length);
    result.add(frame);
  }
  return result.takeBytes();
}

void main() {
  final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
  for (final length in [0, 1, 65535, 65536, 65537, 131077]) {
    test(
      'crypto1 exact frame count and round trip at $length plaintext bytes',
      () async {
        final source = Uint8List.fromList(
          List.generate(length, (i) => i % 251),
        );
        Stream<List<int>> split() async* {
          for (var i = 0; i < length; i += 1031) {
            yield Uint8List.sublistView(source, i, (i + 1031).clamp(0, length));
          }
        }

        final encrypted = await collect(
          crypto.encryptStream(
            plaintext: split(),
            plaintextLength: length,
            password: password,
          ),
        );
        expect(
          frames(encrypted).length,
          1 + (length == 0 ? 1 : (length + 65535) ~/ 65536),
        );
        final restored = await collect(
          crypto.decryptStream(
            container: Stream.value(encrypted),
            password: password,
          ),
        );
        expect(restored, source);
      },
    );
  }
  test(
    'wrong declared plaintext length never emits a valid final container',
    () async {
      await expectLater(
        collect(
          crypto.encryptStream(
            plaintext: Stream.value([1, 2]),
            plaintextLength: 1,
            password: password,
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        collect(
          crypto.encryptStream(
            plaintext: Stream.value([1]),
            plaintextLength: 2,
            password: password,
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'removed final frame and invalid secretstream header are typed authentication',
    () async {
      final data = await crypto.encrypt(
        plaintext: Uint8List(65537),
        password: password,
      );
      final original = frames(data);
      for (final variant in [
        original.sublist(0, original.length - 1),
        [Uint8List(3), ...original.skip(1)],
      ]) {
        await expectLater(
          crypto.decrypt(
            container: withFrames(data, variant),
            password: password,
          ),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'kind',
              BackupFailureKind.authentication,
            ),
          ),
        );
      }
    },
  );
  test('trailing ciphertext is refused after final authentication', () async {
    final data = await crypto.encrypt(
      plaintext: Uint8List(8),
      password: password,
    );
    final tail = Uint8List.fromList([...data, 0]);
    await expectLater(
      crypto.decrypt(container: tail, password: password),
      throwsA(
        isA<BackupProcessingFailure>().having(
          (e) => e.kind,
          'kind',
          BackupFailureKind.authentication,
        ),
      ),
    );
  });
  test(
    'actual reader close failure preserves the preceding rejection',
    () async {
      final data = await crypto.encrypt(
        plaintext: Uint8List(8),
        password: password,
      );
      final source = StreamController<List<int>>(
        onCancel: () => Future.error(StateError('injected close failure')),
      );
      source.add(Uint8List.fromList([...data, 0]));
      await expectLater(
        collect(
          crypto.decryptStream(container: source.stream, password: password),
        ),
        throwsA(
          isA<BackupProcessingCleanupFailure>().having(
            (e) => (e.originalError as BackupProcessingFailure).kind,
            'original',
            BackupFailureKind.authentication,
          ),
        ),
      );
    },
  );
  test(
    'duplicate and excessively nested envelope headers reject before KDF',
    () async {
      var loaded = 0;
      final guarded = BackupCrypto(
        sodiumLoader: () {
          loaded++;
          return loadSodiumForTest();
        },
      );
      for (final header in [
        '{"formatVersion":1,"formatVersion":1}',
        '${'[' * 33}0${']' * 33}',
      ]) {
        final bytes = utf8.encode(header);
        final input = Uint8List.fromList([
          ...ascii.encode('ONTIMEBK'),
          ...(ByteData(4)..setUint32(0, bytes.length)).buffer.asUint8List(),
          ...bytes,
        ]);
        await expectLater(
          guarded.decrypt(container: input, password: password),
          throwsA(isA<BackupProcessingFailure>()),
        );
      }
      expect(loaded, 0);
    },
  );
  test(
    'whole-input capacity rejection occurs before KDF or payload indexing',
    () async {
      var loaded = 0;
      final guarded = BackupCrypto(
        sodiumLoader: () {
          loaded++;
          return loadSodiumForTest();
        },
      );
      await expectLater(
        collect(
          guarded.decryptStream(
            container: Stream.value(
              _UnreadableBytes(BackupLimits.cipherBytes + 1),
            ),
            password: password,
          ),
        ),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      await expectLater(
        collect(
          guarded.encryptStream(
            plaintext: const Stream.empty(),
            plaintextLength: BackupLimits.plainBytes + 1,
            password: password,
          ),
        ),
        throwsA(isA<BackupProcessingFailure>()),
      );
      expect(loaded, 0);
    },
  );
}
