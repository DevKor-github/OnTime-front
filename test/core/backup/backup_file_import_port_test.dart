import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_file_import_port.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const port = NativeBackupFileImportPort();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late Future<Object?> Function(MethodCall) handler;
  setUp(() {
    calls.clear();
    handler = (call) async => switch (call.method) {
      'begin' => 'attempt',
      'pick' => <String, Object?>{'length': null},
      'close' => true,
      _ => throw StateError('Unexpected call'),
    };
    messenger.setMockMethodCallHandler(NativeBackupFileImportPort.channel, (
      call,
    ) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(
    () => messenger.setMockMethodCallHandler(
      NativeBackupFileImportPort.channel,
      null,
    ),
  );

  test(
    'unknown length and short reads continue until actual empty EOF',
    () async {
      var reads = 0;
      final normal = handler;
      handler = (call) async {
        if (call.method != 'read') return normal(call);
        reads++;
        return {
          'bytes': reads == 1 ? Uint8List.fromList([1, 2]) : Uint8List(0),
          'eof': reads == 2,
        };
      };
      final source = (await port.select())!;
      expect(source.declaredLength, isNull);
      expect(await source.openRead().expand((b) => b).toList(), [1, 2]);
      expect(reads, 2);
      expect(calls.where((c) => c.method == 'close').length, 1);
    },
  );

  test(
    'metadata over cap rejects before native read and confirms close',
    () async {
      final normal = handler;
      handler = (call) async => call.method == 'pick'
          ? {'length': BackupLimits.cipherBytes + 1}
          : normal(call);
      await expectLater(
        port.select(),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      expect(calls.map((c) => c.method), ['begin', 'pick', 'close']);
    },
  );

  test('actual cap is accepted only after a one-byte EOF probe', () async {
    final normal = handler;
    var remaining = BackupLimits.cipherBytes;
    final chunk = Uint8List(65536);
    final requested = <int>[];
    handler = (call) async {
      if (call.method != 'read') return normal(call);
      final size = (call.arguments as Map)['maxBytes'] as int;
      requested.add(size);
      if (remaining == 0) return {'bytes': Uint8List(0), 'eof': true};
      remaining -= chunk.length;
      return {'bytes': chunk, 'eof': false};
    };
    final source = (await port.select())!;
    var count = 0;
    await for (final bytes in source.openRead()) {
      count += bytes.length;
    }
    expect(count, BackupLimits.cipherBytes);
    expect(requested.last, 1);
    expect(requested.every((n) => n <= 65536), isTrue);
  });

  test(
    'one byte after actual cap is resource failure even with underreported metadata',
    () async {
      final normal = handler;
      var remaining = BackupLimits.cipherBytes;
      final chunk = Uint8List(65536);
      handler = (call) async {
        if (call.method == 'pick') return {'length': 1};
        if (call.method != 'read') return normal(call);
        if (remaining == 0) return {'bytes': Uint8List(1), 'eof': false};
        remaining -= chunk.length;
        return {'bytes': chunk, 'eof': false};
      };
      final source = (await port.select())!;
      await expectLater(
        source.openRead().drain<void>(),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      expect(calls.last.method, 'close');
    },
  );

  test('zero progress is IO rather than early EOF', () async {
    final normal = handler;
    handler = (call) async => call.method == 'read'
        ? {'bytes': Uint8List(0), 'eof': false}
        : normal(call);
    final source = (await port.select())!;
    await expectLater(
      source.openRead().drain<void>(),
      throwsA(
        isA<BackupProcessingFailure>().having(
          (e) => e.kind,
          'kind',
          BackupFailureKind.inputOutput,
        ),
      ),
    );
  });

  test(
    'cancel waits for close acknowledgement and preserves close failure for retry',
    () async {
      final owner = BackupProcessingOwner();
      final lease = owner.acquire();
      final selected = Completer<Object?>();
      final closed = Completer<Object?>();
      var closes = 0;
      final normal = handler;
      handler = (call) async {
        if (call.method == 'pick') return selected.future;
        if (call.method == 'close') {
          closes++;
          return closed.future;
        }
        return normal(call);
      };
      final selection = port.select(lease: lease);
      await Future<void>.delayed(Duration.zero);
      lease.requestCancellation();
      await Future<void>.delayed(Duration.zero);
      expect(owner.active, same(lease));
      expect(closes, 1);
      selected.complete(null);
      var completed = false;
      final expected = expectLater(
        selection,
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.userCancelled,
          ),
        ),
      ).then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      closed.complete(true);
      await expected;
      lease.release();
      expect(owner.active, isNull);
    },
  );

  test(
    'original read failure and cleanup failure remain distinct, close retry works',
    () async {
      final normal = handler;
      var closes = 0;
      handler = (call) async {
        if (call.method == 'read') {
          throw PlatformException(code: 'import_limit');
        }
        if (call.method == 'close' && closes++ == 0) {
          throw PlatformException(code: 'import_io');
        }
        return normal(call);
      };
      final source = (await port.select())!;
      await expectLater(
        source.openRead().drain<void>(),
        throwsA(
          isA<BackupProcessingCleanupFailure>().having(
            (e) => (e.originalError as BackupProcessingFailure).kind,
            'original',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      await source.close();
      expect(closes, 2);
    },
  );
}
