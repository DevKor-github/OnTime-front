import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_lifecycle.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/startup/startup_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const cutover = 'ontime_local_only_cutover_v1';
  const keyName = 'ontime_local_database_key_v1';
  late Directory root;
  late Map<String, String> storage;
  late List<String> writes;
  var failRead = false;
  var ignoreMarkerWrite = false;
  var ignoreTokenDelete = false;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ontime-d01-bootstrap-');
    storage = {};
    writes = [];
    failRead = false;
    ignoreMarkerWrite = false;
    ignoreTokenDelete = false;
    SharedPreferences.setMockInitialValues({'untouched': 'synthetic'});
    messenger.setMockMethodCallHandler(paths, (_) async => root.path);
    messenger.setMockMethodCallHandler(secure, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          if (key == cutover && failRead) {
            throw PlatformException(code: 'locked');
          }
          return storage[key];
        case 'write':
          writes.add(key);
          if (!(key == cutover && ignoreMarkerWrite)) {
            storage[key] = args['value'] as String;
          }
          return null;
        case 'delete':
          if (!(ignoreTokenDelete && key == 'accessToken')) storage.remove(key);
          return null;
        default:
          throw StateError('Unexpected secure operation');
      }
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(paths, null);
    messenger.setMockMethodCallHandler(secure, null);
    await root.delete(recursive: true);
  });
  test(
    'verified-pair marker repair cannot complete while a legacy token deletion is unconfirmed',
    () async {
      storage['accessToken'] = 'synthetic';
      ignoreTokenDelete = true;
      await expectLater(
        LocalDataLifecycle.repairCutoverAfterVerifiedRestore(),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      expect(storage['accessToken'], 'synthetic');
      expect(storage[cutover], null);
      ignoreTokenDelete = false;
      await LocalDataLifecycle.repairCutoverAfterVerifiedRestore();
      expect(storage['accessToken'], null);
      expect(storage[cutover], 'complete');
    },
  );
  test(
    'new explicit reset cannot supersede unresolved restore authority',
    () async {
      final gate = LocalDataOperationGate.shared;
      gate.setRecoveryPending(true);
      try {
        await expectLater(
          LocalDataLifecycle.beginReset(),
          throwsA(isA<LocalDataUnavailable>()),
        );
        expect(storage, isEmpty);
        expect(writes, isEmpty);
      } finally {
        gate.setRecoveryPending(false);
      }
    },
  );
  for (final mode in ['missing', 'unknown', 'read-failed']) {
    test(
      'actual bootstrap $mode marker preserves existing local DB/key and performs no cutover write',
      () async {
        final file = File('${root.path}/ontime_local_v1.sqlite');
        await file.writeAsBytes([11, 22, 33]);
        final key = base64UrlEncode(List<int>.filled(32, 7));
        storage[keyName] = key;
        if (mode == 'unknown') storage[cutover] = 'unknown-version';
        failRead = mode == 'read-failed';
        await expectLater(
          LocalDataLifecycle.bootstrap(),
          throwsA(isA<LocalStorePreservationRequired>()),
        );
        expect(await file.readAsBytes(), [11, 22, 33]);
        expect(storage[keyName] == key, true);
        expect(writes, isEmpty);
        expect(
          (await SharedPreferences.getInstance()).getString('untouched'),
          'synthetic',
        );
      },
    );
  }
  test(
    'verified legacy-only cutover removes legacy family and reads complete marker back',
    () async {
      final legacy = File('${root.path}/my_database.sqlite');
      await legacy.writeAsBytes([1, 2]);
      await LocalDataLifecycle.bootstrap();
      expect(await legacy.exists(), false);
      expect(storage[cutover], 'complete');
      expect(writes, [cutover]);
      expect(storage.containsKey(keyName), false);
      expect(await File('${root.path}/ontime_local_v1.sqlite').exists(), false);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );
  test(
    'ignored cutover marker write is unconfirmed and never creates local data/key',
    () async {
      ignoreMarkerWrite = true;
      await expectLater(
        LocalDataLifecycle.bootstrap(),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      expect(storage.containsKey(cutover), false);
      expect(storage.containsKey(keyName), false);
      expect(await File('${root.path}/ontime_local_v1.sqlite').exists(), false);
    },
  );
}
