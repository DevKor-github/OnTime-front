import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('on_time_front/backup_files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final bytes = Uint8List.fromList([10, 20, 30]);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'iOS exports encrypted bytes through document UI and returns completion',
    () async {
      MethodCall? observed;
      messenger.setMockMethodCallHandler(channel, (call) async {
        observed = call;
        return true;
      });
      expect(
        await BackupFilePicker(isIOS: true).save(bytes, 'OnTime.ontimebackup'),
        isTrue,
      );
      expect(observed!.method, 'exportBackup');
      expect(observed!.arguments, {
        'bytes': bytes,
        'suggestedName': 'OnTime.ontimebackup',
      });
    },
  );

  test('iOS cancellation is not successful export', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    expect(
      await BackupFilePicker(isIOS: true).save(bytes, 'OnTime.ontimebackup'),
      isFalse,
    );
  });

  test('iOS storage errors propagate to the existing recovery UI', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'exportFailed');
    });
    await expectLater(
      BackupFilePicker(isIOS: true).save(bytes, 'OnTime.ontimebackup'),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'exportFailed'),
      ),
    );
  });
}
