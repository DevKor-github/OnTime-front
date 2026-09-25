// Structured synthetic QA evidence is intentionally emitted to captured logs.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import '../../helpers/sodium_test_loader.dart';

void main() {
  test(
    'actual 64MiB plaintext round trips with locked sodium without a plaintext spool or joined container',
    () async {
      final dir = await Directory.systemTemp.createTemp('d05-capacity-');
      addTearDown(() => dir.delete(recursive: true));
      final encrypted = File('${dir.path}/ciphertext');
      final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
      final chunk = Uint8List.fromList(List.generate(65536, (i) => i % 251));
      Stream<List<int>> source() async* {
        for (var i = 0; i < 1024; i++) {
          yield chunk;
        }
      }

      final writer = encrypted.openWrite();
      final outputBudget = BackupBudget();
      final timer = Stopwatch()..start();
      await writer.addStream(
        crypto.encryptStream(
          plaintext: source(),
          plaintextLength: BackupLimits.plainBytes,
          password: 'Synthetic exact capacity password',
          budget: outputBudget,
        ),
      );
      await writer.flush();
      await writer.close();
      expect(outputBudget.plainBytes, BackupLimits.plainBytes);
      expect(
        await encrypted.length(),
        lessThanOrEqualTo(BackupLimits.cipherBytes),
      );
      final inputBudget = BackupBudget();
      final hash = await sha256
          .bind(
            crypto.decryptStream(
              container: encrypted.openRead(),
              password: 'Synthetic exact capacity password',
              budget: inputBudget,
            ),
          )
          .single;
      expect(hash, await sha256.bind(source()).single);
      expect(inputBudget.plainBytes, BackupLimits.plainBytes);
      print(
        'D05_ACTUAL_CRYPTO_CAP plain=${inputBudget.plainBytes} cipher=${inputBudget.cipherBytes} elapsedMs=${timer.elapsedMilliseconds} hostPeakRss=${ProcessInfo.maxRss}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'stream exceeding exact admitted length never completes encryption or emits success',
    () async {
      final crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
      final chunk = Uint8List(65536);
      Stream<List<int>> source() async* {
        for (var i = 0; i < 1024; i++) {
          yield chunk;
        }
        yield [1];
      }

      await expectLater(
        crypto
            .encryptStream(
              plaintext: source(),
              plaintextLength: BackupLimits.plainBytes,
              password: 'Synthetic exact capacity password',
            )
            .drain<void>(),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
