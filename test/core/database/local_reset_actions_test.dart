import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/database/local_reset_actions.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'private': 'fixture'});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('marker absence is read back after deletion', () async {
    final storage = _IgnoredDeletes();
    final actions = DeviceLocalResetActions(storage: storage);
    await actions.writeMarker();
    expect(await actions.hasMarker(), true);
    await expectLater(
      actions.removeMarker(),
      throwsA(isA<AlarmJournalUnavailable>()),
    );
    expect(await actions.hasMarker(), true);
  });

  test(
    'an acknowledged but ignored intent write never authorizes deletion',
    () async {
      final actions = DeviceLocalResetActions(storage: _IgnoredWrites());
      await expectLater(
        actions.writeMarker(),
        throwsA(isA<AlarmJournalUnavailable>()),
      );
      expect(await actions.hasMarker(), false);
    },
  );

  test(
    'key deletion checks absence without creating another installation key',
    () async {
      final storage = _IgnoredDeletes();
      final keys = InstallationKeyStore(storage: storage);
      final original = await keys.getOrCreate();
      final actions = DeviceLocalResetActions(
        keyStore: keys,
        removePairKeys: () async {},
      );
      await expectLater(
        actions.perform(ResetStep.key),
        throwsA(isA<AlarmJournalUnavailable>()),
      );
      expect(await keys.getOrCreate(), original);
      final working = InstallationKeyStore();
      await DeviceLocalResetActions(
        keyStore: working,
        removePairKeys: () async {},
      ).perform(ResetStep.key);
      expect(await working.exists(), false);
    },
  );

  test(
    'credential deletion does not accept a successful call with remaining data',
    () async {
      const normal = FlutterSecureStorage();
      await normal.write(key: 'accessToken', value: 'fixture');
      final actions = DeviceLocalResetActions(storage: _IgnoredDeletes());
      await expectLater(
        actions.perform(ResetStep.credentials),
        throwsA(isA<AlarmJournalUnavailable>()),
      );
      await DeviceLocalResetActions().perform(ResetStep.credentials);
      expect(await normal.read(key: 'accessToken'), isNull);
    },
  );

  test(
    'database is closed before file deletion and a file failure propagates',
    () async {
      final calls = <String>[];
      final actions = DeviceLocalResetActions(
        closeDatabase: () async {
          calls.add('close');
        },
        deleteFiles: () async {
          calls.add('delete');
          throw StateError('fixture');
        },
      );
      await expectLater(actions.perform(ResetStep.database), throwsStateError);
      expect(calls, ['close', 'delete']);
    },
  );

  test('preferences stage verifies empty storage', () async {
    await DeviceLocalResetActions().perform(ResetStep.preferences);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test(
    'global cleanup receipt requires both native and notification completion',
    () async {
      var notificationsFail = true;
      final actions = DeviceLocalResetActions(
        clearNativeDeliveries: () async => true,
        clearDeliveries: () async {
          if (notificationsFail) throw StateError('fixture');
        },
      );
      await expectLater(
        actions.perform(ResetStep.deliveries),
        throwsStateError,
      );
      expect(actions.allProvidersConfirmedEmpty, false);
      notificationsFail = false;
      await actions.perform(ResetStep.deliveries);
      expect(actions.allProvidersConfirmedEmpty, true);
      final android = DeviceLocalResetActions(
        clearNativeDeliveries: () async => false,
        clearDeliveries: () async {},
      );
      await android.perform(ResetStep.deliveries);
      expect(android.allProvidersConfirmedEmpty, false);
    },
  );

  test(
    'native launch cleanup is required and platform errors propagate',
    () async {
      const channel = MethodChannel('on_time_front/native_alarm');
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            throw PlatformException(code: 'cleanupUnconfirmed');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(
        DeviceLocalResetActions().perform(ResetStep.launch),
        throwsA(isA<PlatformException>()),
      );
      expect(methods, ['clearStoredLaunchPayload']);
    },
  );
}

class _IgnoredDeletes extends FlutterSecureStorage {
  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

class _IgnoredWrites extends FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}
