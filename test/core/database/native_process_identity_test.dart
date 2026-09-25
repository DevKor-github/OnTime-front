import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/recovery/native_process_identity.dart';
import 'package:on_time_front/core/database/recovery/store_pair.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('on_time_front/native_alarm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'native opaque process identity is consumed unchanged across calls',
    () async {
      const nonce = '10000000-0000-4000-8000-000000000001';
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getProcessIdentity');
        expect(call.arguments, null);
        return nonce;
      });
      expect(await readNativeProcessIdentity(), nonce);
      expect(await readNativeProcessIdentity(), nonce);
    },
  );
  for (final value in [
    null,
    '',
    'device-id',
    '10000000-0000-0000-8000-000000000001',
  ]) {
    test(
      'missing or invalid native identity never invents a restart: $value',
      () async {
        messenger.setMockMethodCallHandler(channel, (_) async => value);
        await expectLater(
          readNativeProcessIdentity(),
          throwsA(isA<PairAuthorityUnavailable>()),
        );
      },
    );
  }
  test('unavailable channel remains unknown', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    await expectLater(
      readNativeProcessIdentity(),
      throwsA(isA<PlatformException>()),
    );
  });
}
