import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_file_export_port.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const port = NativeBackupFileExportPort();
  late BackupProcessingOwner owner;
  late BackupProcessingLease lease;
  late List<MethodCall> calls;
  late BytesBuilder file;
  var outcome = 'saved';
  var cleanupPending = false;
  Future<Object?> native(MethodCall call) async {
    calls.add(call);
    final args = call.arguments as Map;
    switch (call.method) {
      case 'begin':
        expect(args, {'suggestedName': 'test.ontimebackup'});
        return 'opaque-attempt';
      case 'append':
        expect(args['handle'], 'opaque-attempt');
        expect(
          args['sequence'],
          calls.where((c) => c.method == 'append').length - 1,
        );
        final bytes = args['bytes'] as Uint8List;
        expect(bytes.length, inInclusiveRange(1, 65536));
        file.add(bytes);
        return true;
      case 'seal':
        final bytes = file.toBytes();
        expect(args['length'], bytes.length);
        expect(args['sha256'], sha256.convert(bytes).toString());
        return true;
      case 'export':
      case 'cancel':
        return {'outcome': outcome, 'cleanupUnconfirmed': cleanupPending};
      default:
        fail('unexpected method');
    }
  }

  Future<BackupFileExportReceipt> run(Stream<List<int>> input) =>
      port.exportStream(
        encrypted: input,
        suggestedName: 'test.ontimebackup',
        lease: lease,
      );
  setUp(() {
    owner = BackupProcessingOwner();
    lease = owner.acquire();
    calls = [];
    file = BytesBuilder(copy: false);
    outcome = 'saved';
    cleanupPending = false;
    messenger.setMockMethodCallHandler(
      NativeBackupFileExportPort.channel,
      native,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      NativeBackupFileExportPort.channel,
      null,
    );
  });

  test(
    'opaque handle with strict bounded acknowledged chunks and independent seal digest',
    () async {
      final input = Uint8List.fromList(List.generate(131091, (i) => i % 251));
      expect(await run(Stream.value(input)), BackupFileExportReceipt.saved);
      expect(file.toBytes(), input);
      expect(calls.map((c) => c.method), [
        'begin',
        'append',
        'append',
        'append',
        'seal',
        'export',
      ]);
      expect(
        calls
            .where((c) => c.method == 'append')
            .map((c) => (c.arguments['bytes'] as Uint8List).length),
        [65536, 65536, 19],
      );
    },
  );
  test('append awaits ack before requesting another source chunk', () async {
    final ack = Completer<bool>();
    var produced = 0;
    messenger.setMockMethodCallHandler(NativeBackupFileExportPort.channel, (
      call,
    ) async {
      if (call.method == 'append' && produced == 1) {
        await ack.future;
      }
      return native(call);
    });
    Stream<List<int>> input() async* {
      produced++;
      yield [1];
      produced++;
      yield [2];
    }

    final pending = run(input());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(produced, 1);
    ack.complete(true);
    expect(await pending, BackupFileExportReceipt.saved);
    expect(produced, 2);
  });
  test('cancel receipt never marks saved', () async {
    outcome = 'cancelled';
    expect(await run(Stream.value([1])), BackupFileExportReceipt.cancelled);
  });
  test(
    'source failure cannot seal or open picker and closes same owner',
    () async {
      outcome = 'failed';
      await expectLater(
        run(
          Stream.error(
            const BackupProcessingFailure(
              BackupFailureKind.resourceLimit,
              'plainBytes',
            ),
          ),
        ),
        throwsA(isA<BackupProcessingFailure>()),
      );
      expect(calls.map((c) => c.method), ['begin', 'cancel']);
    },
  );
  test(
    'platform resource failure retains typed kind without provider path',
    () async {
      messenger.setMockMethodCallHandler(NativeBackupFileExportPort.channel, (
        call,
      ) async {
        if (call.method == 'append') {
          throw PlatformException(
            code: 'export_limit',
            message: '/private/provider',
          );
        }
        return native(call);
      });
      outcome = 'failed';
      await expectLater(
        run(Stream.value([1])),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      expect(calls.last.method, 'cancel');
    },
  );
  test(
    'saved remains saved when cleanup is unconfirmed and retry keeps ownership',
    () async {
      cleanupPending = true;
      expect(await run(Stream.value([1])), BackupFileExportReceipt.saved);
      expect(owner.active, same(lease));
      expect(lease.phase, BackupProcessingPhase.cleanupPending);
      cleanupPending = false;
      await owner.retryCleanup();
      expect(owner.active, isNull);
    },
  );
  test('failure plus cleanup failure is retained and actionable', () async {
    outcome = 'failed';
    var closes = 0;
    messenger.setMockMethodCallHandler(NativeBackupFileExportPort.channel, (
      call,
    ) async {
      if (call.method == 'cancel' && ++closes == 1) {
        throw PlatformException(code: 'export_io');
      }
      return native(call);
    });
    await expectLater(
      run(
        Stream.error(
          const BackupProcessingFailure(BackupFailureKind.userCancelled),
        ),
      ),
      throwsA(isA<BackupProcessingCleanupFailure>()),
    );
    expect(owner.active, same(lease));
    await owner.retryCleanup();
    expect(owner.active, isNull);
    expect(closes, 2);
  });
  test(
    'cancel during append waits for append return and authoritative saved wins',
    () async {
      final append = Completer<bool>();
      final entered = Completer<void>();
      messenger.setMockMethodCallHandler(NativeBackupFileExportPort.channel, (
        call,
      ) async {
        if (call.method == 'append') {
          entered.complete();
          await append.future;
        }
        return native(call);
      });
      var complete = false;
      final pending = run(Stream.value([1])).then((v) {
        complete = true;
        return v;
      });
      await entered.future;
      lease.requestCancellation();
      await Future<void>.delayed(Duration.zero);
      expect(complete, false);
      append.complete(true);
      expect(await pending, BackupFileExportReceipt.saved);
      expect(calls.any((c) => c.method == 'export'), false);
    },
  );
  for (final invalid in [
    null,
    'saved',
    {'outcome': 'unknown', 'cleanupUnconfirmed': false},
  ]) {
    test('invalid receipt $invalid is not success', () async {
      messenger.setMockMethodCallHandler(NativeBackupFileExportPort.channel, (
        call,
      ) async {
        if (call.method == 'export') return invalid;
        if (call.method == 'cancel') {
          return {'outcome': 'failed', 'cleanupUnconfirmed': false};
        }
        return native(call);
      });
      await expectLater(
        run(Stream.value([1])),
        throwsA(anyOf(isA<BackupFileExportFailure>(), isA<TypeError>())),
      );
    });
  }
}
