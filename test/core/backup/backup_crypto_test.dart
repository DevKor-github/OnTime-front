import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import '../../helpers/sodium_test_loader.dart';

void main() {
  const password = 'correct horse battery';
  final plaintext = Uint8List.fromList(utf8.encode('offline schedule backup'));

  test('round trip restores the authenticated plaintext', () async {
    final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);

    final encrypted = await crypto.encrypt(
      plaintext: plaintext,
      password: password,
    );
    final restored = await crypto.decrypt(
      container: encrypted,
      password: password,
    );

    expect(restored, plaintext);
    expect(
      utf8.decode(encrypted, allowMalformed: true),
      isNot(contains('offline schedule backup')),
    );
  });

  test('wrong password cannot produce backup contents', () async {
    final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
    final encrypted = await crypto.encrypt(
      plaintext: plaintext,
      password: password,
    );

    await expectLater(
      crypto.decrypt(
        container: encrypted,
        password: 'incorrect password 123',
      ),
      throwsFormatException,
    );
  });

  test('authenticated encryption detects a modified container', () async {
    final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
    final encrypted = await crypto.encrypt(
      plaintext: plaintext,
      password: password,
    );
    encrypted[encrypted.length - 1] ^= 1;

    await expectLater(
      crypto.decrypt(container: encrypted, password: password),
      throwsFormatException,
    );
  });
}
