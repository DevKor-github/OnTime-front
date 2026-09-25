import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

import '../../helpers/sodium_test_loader.dart';
import 'backup_crypto_stream_test.dart' as fixture;

// Contract: no modified or incomplete authenticated container may successfully
// finish decryption. Partial stream chunks are provisional, never preview-ready.
const _password = 'Synthetic T03 matrix password';
Uint8List _u32(int n) => (ByteData(4)..setUint32(0, n)).buffer.asUint8List();
int _headerLength(Uint8List data) =>
    ByteData.sublistView(data, 8, 12).getUint32(0);
Uint8List _header(Uint8List data) =>
    Uint8List.sublistView(data, 12, 12 + _headerLength(data));
Uint8List _replaceHeader(Uint8List data, List<int> header) =>
    Uint8List.fromList([
      ...data.take(8),
      ..._u32(header.length),
      ...header,
      ...data.skip(12 + _headerLength(data)),
    ]);
Uint8List _flip(Uint8List data, int at) {
  final copy = Uint8List.fromList(data);
  copy[at] ^= 1;
  return copy;
}

Uint8List _setNumber(Uint8List data, int offset, int n) {
  final copy = Uint8List.fromList(data);
  copy.setRange(offset, offset + 4, _u32(n));
  return copy;
}

void main() {
  final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
  final plaintext = Uint8List.fromList(List.generate(131077, (i) => i % 251));
  final shortPlaintext = Uint8List.fromList(
    utf8.encode('Synthetic matrix bytes'),
  );
  late Uint8List encrypted;
  late Uint8List otherStream;
  late Uint8List shortEncrypted;
  setUpAll(() async {
    encrypted = await crypto.encrypt(plaintext: plaintext, password: _password);
    otherStream = await crypto.encrypt(
      plaintext: plaintext,
      password: _password,
    );
    shortEncrypted = await crypto.encrypt(
      plaintext: shortPlaintext,
      password: _password,
    );
  });

  test(
    'T03 C02 C03 malformed envelope variants reject before sodium loads',
    () async {
      var loaded = 0;
      final guarded = BackupCrypto(
        sodiumLoader: () {
          loaded++;
          return loadSodiumForTest();
        },
      );
      final original =
          jsonDecode(utf8.decode(_header(encrypted))) as Map<String, dynamic>;
      final variants = <String, Uint8List>{
        'magic changed': _flip(encrypted, 0),
        'magic truncated': Uint8List.sublistView(encrypted, 0, 7),
        'length truncated': Uint8List.sublistView(encrypted, 0, 11),
        'zero length': _setNumber(encrypted, 8, 0),
        'header cap plus one': _setNumber(encrypted, 8, 4097),
        'header cap invalid JSON': _replaceHeader(
          encrypted,
          List.filled(4096, 32),
        ),
        'invalid UTF8': _replaceHeader(encrypted, [0xff]),
        'invalid escape': _replaceHeader(
          encrypted,
          utf8.encode(r'{"salt":"\q"}'),
        ),
        'duplicate escaped key': _replaceHeader(
          encrypted,
          utf8.encode(r'{"salt":"a","\u0073alt":"b"}'),
        ),
        'array header': _replaceHeader(encrypted, utf8.encode('[]')),
        'null header': _replaceHeader(encrypted, utf8.encode('null')),
      };
      for (final field in original.keys) {
        final absent = Map<String, dynamic>.from(original)..remove(field);
        variants['missing $field'] = _replaceHeader(
          encrypted,
          utf8.encode(jsonEncode(absent)),
        );
        final wrongType = Map<String, dynamic>.from(original)..[field] = false;
        variants['wrong type $field'] = _replaceHeader(
          encrypted,
          utf8.encode(jsonEncode(wrongType)),
        );
      }
      for (final entry in <String, Object>{
        'formatVersion': 2,
        'suite': 'unsupported-suite',
        'opsLimit': 4,
        'memLimit': 1,
        'chunkSize': 1,
        'salt': base64UrlEncode(Uint8List(15)),
      }.entries) {
        final changed = Map<String, dynamic>.from(original)
          ..[entry.key] = entry.value;
        variants['unsupported ${entry.key}'] = _replaceHeader(
          encrypted,
          utf8.encode(jsonEncode(changed)),
        );
      }
      variants['salt invalid base64'] = _replaceHeader(
        encrypted,
        utf8.encode(jsonEncode({...original, 'salt': '!'})),
      );
      for (final entry in variants.entries) {
        await expectLater(
          guarded.decrypt(container: entry.value, password: _password),
          throwsA(isA<BackupProcessingFailure>()),
          reason: entry.key,
        );
        expect(loaded, 0, reason: entry.key);
      }
      expect(
        await guarded.decrypt(container: shortEncrypted, password: _password),
        shortPlaintext,
      );
      expect(loaded, 1);
    },
  );

  test(
    'T03 C04 supported header bytes salt and stream header require actual authentication',
    () async {
      var loaded = 0;
      final actual = BackupCrypto(
        sodiumLoader: () {
          loaded++;
          return loadSodiumForTest();
        },
      );
      final original =
          jsonDecode(utf8.decode(_header(shortEncrypted)))
              as Map<String, dynamic>;
      final salt = base64Url.decode(original['salt'] as String)..[0] ^= 1;
      final originalFrames = fixture.frames(shortEncrypted);
      final variants = <String, Uint8List>{
        // Identical supported metadata with different serialized bytes proves AAD
        // binding without depending on a rejected algorithm or unsafe KDF value.
        'same metadata changed whitespace': _replaceHeader(
          shortEncrypted,
          utf8.encode(' ${utf8.decode(_header(shortEncrypted))}'),
        ),
        'supported salt changed': _replaceHeader(
          shortEncrypted,
          utf8.encode(jsonEncode({...original, 'salt': base64UrlEncode(salt)})),
        ),
        'same length stream header changed': fixture.withFrames(
          shortEncrypted,
          [_flip(originalFrames.first, 0), ...originalFrames.skip(1)],
        ),
      };
      for (final entry in variants.entries) {
        final before = loaded;
        await expectLater(
          actual.decrypt(container: entry.value, password: _password),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'kind',
              BackupFailureKind.authentication,
            ),
          ),
          reason: entry.key,
        );
        expect(loaded, before + 1, reason: entry.key);
      }
      expect(
        await actual.decrypt(container: shortEncrypted, password: _password),
        shortPlaintext,
      );
    },
  );

  test(
    'T03 C05 frame count admission precedes KDF and structural frame failures never complete',
    () async {
      var loaded = 0;
      final guarded = BackupCrypto(
        sodiumLoader: () {
          loaded++;
          return loadSodiumForTest();
        },
      );
      final countAt = 12 + _headerLength(shortEncrypted);
      for (final count in [0, 1, 100001]) {
        await expectLater(
          guarded.decrypt(
            container: _setNumber(shortEncrypted, countAt, count),
            password: _password,
          ),
          throwsA(isA<BackupProcessingFailure>()),
          reason: 'count $count',
        );
        expect(loaded, 0);
      }
      final variants = <String, Uint8List>{
        'count larger than actual': _setNumber(shortEncrypted, countAt, 3),
        'zero frame length': _setNumber(shortEncrypted, countAt + 4, 0),
        'oversize frame length': _setNumber(
          shortEncrypted,
          countAt + 4,
          65536 + 1024 + 1,
        ),
        'frame length prefix truncated': Uint8List.sublistView(
          shortEncrypted,
          0,
          countAt + 7,
        ),
        'header frame truncated': Uint8List.sublistView(
          shortEncrypted,
          0,
          countAt + 9,
        ),
      };
      for (final entry in variants.entries) {
        await expectLater(
          guarded.decrypt(container: entry.value, password: _password),
          throwsA(isA<BackupProcessingFailure>()),
          reason: entry.key,
        );
      }
      expect(
        await guarded.decrypt(container: shortEncrypted, password: _password),
        shortPlaintext,
      );
    },
  );

  test(
    'T03 C06 first middle last tamper reordering duplication omission and foreign frames reject',
    () async {
      final original = fixture.frames(encrypted);
      expect(original.length, 4); // stream header plus three real data frames
      final variants = <String, List<Uint8List>>{
        for (var i = 1; i <= 3; i++)
          'ciphertext frame $i changed': [
            for (var n = 0; n < original.length; n++)
              n == i ? _flip(original[n], 0) : original[n],
          ],
        'swap first and middle': [
          original[0],
          original[2],
          original[1],
          original[3],
        ],
        'duplicate first data frame': [
          original[0],
          original[1],
          original[1],
          original[2],
          original[3],
        ],
        'omit middle': [original[0], original[1], original[3]],
        'foreign middle frame': [
          original[0],
          original[1],
          fixture.frames(otherStream)[2],
          original[3],
        ],
      };
      for (final entry in variants.entries) {
        await expectLater(
          crypto.decrypt(
            container: fixture.withFrames(encrypted, entry.value),
            password: _password,
          ),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'kind',
              BackupFailureKind.authentication,
            ),
          ),
          reason: entry.key,
        );
      }
      expect(
        await crypto.decrypt(container: encrypted, password: _password),
        plaintext,
      );
    },
  );

  test(
    'T03 C07 C08 authenticated early final cannot hide extra frames or concatenated containers',
    () async {
      final shortFrames = fixture.frames(shortEncrypted);
      final multi = fixture.frames(encrypted);
      final variants = <String, Uint8List>{
        // Both first frames are genuinely authenticated, including finalPush;
        // the appended frame is not a fabricated change to the final tag byte.
        'valid final followed by duplicate final frame': fixture.withFrames(
          shortEncrypted,
          [...shortFrames, shortFrames.last],
        ),
        'valid final followed by another stream frame': fixture.withFrames(
          shortEncrypted,
          [...shortFrames, multi[1]],
        ),
        'authenticated message frames but no final': fixture.withFrames(
          encrypted,
          multi.sublist(0, multi.length - 1),
        ),
        'two complete containers': Uint8List.fromList([
          ...shortEncrypted,
          ...encrypted,
        ]),
        'truncated final frame': Uint8List.sublistView(
          shortEncrypted,
          0,
          shortEncrypted.length - 1,
        ),
      };
      for (final entry in variants.entries) {
        await expectLater(
          crypto.decrypt(container: entry.value, password: _password),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.kind,
              'kind',
              BackupFailureKind.authentication,
            ),
          ),
          reason: entry.key,
        );
      }
      expect(
        await crypto.decrypt(container: shortEncrypted, password: _password),
        shortPlaintext,
      );
    },
  );

  test(
    'T03 C10 one byte provider chunks preserve authenticated bytes and reject a split malformed header',
    () async {
      Stream<List<int>> split(Uint8List source, int size) async* {
        for (var at = 0; at < source.length; at += size) {
          yield Uint8List.sublistView(
            source,
            at,
            (at + size).clamp(0, source.length),
          );
        }
      }

      for (final size in [1, 3, 17]) {
        expect(
          await fixture.collect(
            crypto.decryptStream(
              container: split(shortEncrypted, size),
              password: _password,
            ),
          ),
          shortPlaintext,
          reason: 'provider chunk $size',
        );
      }
      await expectLater(
        fixture.collect(
          crypto.decryptStream(
            container: split(_replaceHeader(shortEncrypted, [0xff]), 1),
            password: _password,
          ),
        ),
        throwsA(isA<BackupProcessingFailure>()),
      );
    },
  );
}
