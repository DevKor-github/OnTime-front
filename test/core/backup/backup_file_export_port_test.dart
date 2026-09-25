import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_file_export_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const port = NativeBackupFileExportPort();

  tearDown(
    () => messenger.setMockMethodCallHandler(
      NativeBackupFileExportPort.channel,
      null,
    ),
  );

  test(
    'sends encrypted bytes and name only; saved receipt has no location',
    () async {
      messenger.setMockMethodCallHandler(NativeBackupFileExportPort.channel, (
        call,
      ) async {
        expect(call.method, 'export');
        expect(call.arguments, {
          'encryptedBytes': [1, 2, 3],
          'suggestedName': 'test.ontimebackup',
        });
        return 'saved';
      });
      expect(
        await port.export(
          encryptedBytes: Uint8List.fromList([1, 2, 3]),
          suggestedName: 'test.ontimebackup',
        ),
        BackupFileExportReceipt.saved,
      );
    },
  );

  test('cancel is distinct from success', () async {
    messenger.setMockMethodCallHandler(
      NativeBackupFileExportPort.channel,
      (_) async => 'cancelled',
    );
    expect(
      await port.export(encryptedBytes: Uint8List(1), suggestedName: 'test'),
      BackupFileExportReceipt.cancelled,
    );
  });

  for (final response in [null, '', 'unknown']) {
    test('unrecognized native response $response is never success', () async {
      messenger.setMockMethodCallHandler(
        NativeBackupFileExportPort.channel,
        (_) async => response,
      );
      await expectLater(
        port.export(encryptedBytes: Uint8List(1), suggestedName: 'test'),
        throwsA(isA<BackupFileExportFailure>()),
      );
    });
  }
}
