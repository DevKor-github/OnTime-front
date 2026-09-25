import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:on_time_front/core/database/local_reset_actions.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/initial_store_guard_native.dart';
import 'package:on_time_front/core/database/installation_key_store.dart';
import 'package:on_time_front/core/startup/startup_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late File file;
  late InstallationKeyStore keys;
  late InitialStoreGuard guard;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('ontime-d01-');
    file = File('${root.path}/ontime_local_v1.sqlite');
    keys = InstallationKeyStore();
    guard = InitialStoreGuard(file, keys, protect: (_) async {});
  });
  tearDown(() async => root.delete(recursive: true));
  for (final checkpoint in [1, 2, 3, 4, 5]) {
    test(
      'creation interruption at protection checkpoint $checkpoint preserves owned evidence',
      () async {
        var calls = 0;
        final interrupted = InitialStoreGuard(
          file,
          keys,
          protect: (_) async {
            if (++calls == checkpoint) {
              throw StateError('injected interruption');
            }
          },
        );
        await expectLater(
          interrupted.prepareOpen().then((_) => true),
          throwsA(isA<LocalStorePreservationRequired>()),
        );
        final priorKey = await keys.readExisting();
        final priorReceipt = await guard.receiptFile.exists()
            ? await guard.receiptFile.readAsString()
            : null;
        if (checkpoint == 2) {
          // An uncommitted temp-only reservation is not ownership authority.
          await expectLater(
            guard.prepareOpen().then((_) => true),
            throwsA(isA<LocalStorePreservationRequired>()),
          );
          expect(await file.exists(), false);
          expect(await keys.exists(), false);
        } else {
          final key = await guard.prepareOpen();
          if (priorKey != null) {
            expect(base64Encode(key) == base64Encode(priorKey), true);
          }
          if (priorReceipt != null) {
            expect(
              jsonDecode(await guard.receiptFile.readAsString())['owner'],
              jsonDecode(priorReceipt)['owner'],
            );
          }
          expect(await file.length(), 0);
        }
      },
    );
  }
  test(
    'secure key read failure is not absence and cannot create a receipt or file',
    () async {
      final storage = _Unreadable();
      final guarded = InitialStoreGuard(
        file,
        InstallationKeyStore(storage: storage),
        protect: (_) async {},
      );
      await expectLater(
        guarded.prepareOpen().then((_) => true),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      await expectLater(
        guarded.requireNoLocalEvidence(),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      expect(storage.writes, 0);
      expect(await root.list().toList(), isEmpty);
    },
  );
  test(
    'malformed ownership metadata preserves bytes and cannot create a key',
    () async {
      await guard.receiptFile.writeAsString('unreadable prior ownership');
      await expectLater(
        guard.prepareOpen().then((_) => true),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      expect(
        await guard.receiptFile.readAsString(),
        'unreadable prior ownership',
      );
      expect(await keys.exists(), false);
      expect(await file.exists(), false);
    },
  );
  test(
    'explicit reset database stage removes and reads back fixed creation receipts',
    () async {
      await guard.prepareOpen();
      await guard.temporaryReceipt.writeAsString('interrupted metadata');
      final actions = DeviceLocalResetActions(
        deleteFiles: () async {
          await file.delete();
        },
        removeCreationReceipt: guard.removeReceipt,
        removePairKeys:
            () async {}, // This fixed-store fixture has no pair slots.
      );
      await actions.perform(ResetStep.database);
      expect(await guard.receiptFile.exists(), false);
      expect(await guard.temporaryReceipt.exists(), false);
      // The distinct key stage remains responsible for key removal.
      expect(await keys.exists(), true);
      await actions.perform(ResetStep.key);
      expect(await keys.exists(), false);
    },
  );
  test(
    'completion unlink failure keeps verified ownership and retries the same key/file',
    () async {
      final originalKey = await guard.prepareOpen();
      // Cipher/schema proof is covered separately with actual SQLCipher. Here the
      // caller has crossed that boundary and injects only the metadata unlink fault.
      await file.writeAsBytes([9, 8, 7]);
      final fault = InitialStoreGuard(
        file,
        keys,
        protect: (_) async {},
        removeCompletedReceipt: (_) async =>
            throw FileSystemException('unlink unconfirmed'),
      );
      await expectLater(
        fault.completeVerifiedCreation(),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        jsonDecode(await guard.receiptFile.readAsString())['stage'],
        'verified',
      );
      final resumed = await guard.prepareOpen();
      expect(base64Encode(originalKey) == base64Encode(resumed), true);
      expect(await file.readAsBytes(), [9, 8, 7]);
      await guard.completeVerifiedCreation();
      expect(await guard.receiptFile.exists(), false);
      expect(await file.readAsBytes(), [9, 8, 7]);
    },
  );
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    test(
      'unowned $suffix family evidence prevents cutover and key creation',
      () async {
        final member = File('${file.path}$suffix');
        await member.writeAsBytes([1, 2, 3]);
        await expectLater(
          guard.requireNoLocalEvidence(),
          throwsA(isA<LocalStorePreservationRequired>()),
        );
        await expectLater(
          guard.prepareOpen().then((_) => true),
          throwsA(isA<LocalStorePreservationRequired>()),
        );
        expect(await member.readAsBytes(), [1, 2, 3]);
        expect(await keys.exists(), false);
        expect(await guard.receiptFile.exists(), false);
      },
    );
  }
  test('unowned key-only and zero-byte file are preserved', () async {
    final key = await keys.createVerified();
    await expectLater(
      guard.prepareOpen().then((_) => true),
      throwsA(isA<LocalStorePreservationRequired>()),
    );
    await file.create();
    await expectLater(
      guard.prepareOpen().then((_) => true),
      throwsA(isA<LocalStorePreservationRequired>()),
    );
    expect(await keys.readExisting(), key);
    expect(await file.length(), 0);
  });
  test(
    'new creation writes metadata ownership before key/file and resumes same key',
    () async {
      final a = await guard.prepareOpen();
      final metadata =
          jsonDecode(await guard.receiptFile.readAsString()) as Map;
      expect(metadata.keys.toSet(), {
        'version',
        'owner',
        'stage',
        'store',
        'keySlot',
      });
      expect(metadata['stage'], 'keyReady');
      expect(await file.length(), 0);
      final restarted = InitialStoreGuard(file, keys, protect: (_) async {});
      expect(await restarted.prepareOpen(), a);
      expect(await keys.readExisting(), a);
      await expectLater(
        restarted.completeVerifiedCreation(),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
    },
  );
  test(
    'receipt never authorizes replacing missing key for existing file',
    () async {
      await guard.prepareOpen();
      await keys.delete();
      await expectLater(
        guard.prepareOpen().then((_) => true),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      expect(await keys.exists(), false);
      expect(await file.length(), 0);
    },
  );
  test(
    'uncertain key write reads back same value without a second write',
    () async {
      final storage = _WrittenThenError();
      final keys = InstallationKeyStore(storage: storage);
      final key = await keys.createVerified();
      expect(await keys.readExisting(), key);
      expect(storage.writes, 1);
    },
  );
  test(
    'activation evidence prevents fresh classification without modifying fixed store',
    () async {
      final blocked = InitialStoreGuard(
        file,
        keys,
        protect: (_) async {},
        activationEvidence: () async => true,
      );
      await expectLater(
        blocked.prepareOpen(),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      expect(await keys.exists(), false);
      expect(await root.list().toList(), isEmpty);
    },
  );
  test(
    'verified receipt with missing store cannot regress to empty creation',
    () async {
      final key = await guard.prepareOpen();
      final metadata =
          jsonDecode(await guard.receiptFile.readAsString())
              as Map<String, dynamic>;
      metadata['stage'] = 'verified';
      await guard.receiptFile.writeAsString(jsonEncode(metadata));
      await file.delete();
      await expectLater(
        guard.prepareOpen().then((_) => true),
        throwsA(isA<LocalStorePreservationRequired>()),
      );
      expect(await file.exists(), false);
      expect(await keys.readExisting(), key);
      expect(
        jsonDecode(await guard.receiptFile.readAsString())['stage'],
        'verified',
      );
    },
  );
  test('reserved receipt does not own an unexpected zero-byte file', () async {
    await guard.prepareOpen();
    final metadata =
        jsonDecode(await guard.receiptFile.readAsString())
            as Map<String, dynamic>;
    metadata['stage'] = 'reserved';
    await guard.receiptFile.writeAsString(jsonEncode(metadata));
    await expectLater(
      guard.prepareOpen().then((_) => true),
      throwsA(isA<LocalStorePreservationRequired>()),
    );
    expect(await file.length(), 0);
  });
  test('receipt symlink is not followed', () async {
    final sentinel = File('${root.path}/sentinel');
    await sentinel.writeAsString('preserve');
    await Link(guard.receiptFile.path).create(sentinel.path);
    await expectLater(
      guard.prepareOpen().then((_) => true),
      throwsA(isA<LocalStorePreservationRequired>()),
    );
    expect(await sentinel.readAsString(), 'preserve');
  });
}

class _WrittenThenError extends FlutterSecureStorage {
  int writes = 0;
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
  }) async {
    writes++;
    await super.write(key: key, value: value, iOptions: iOptions);
    throw StateError('response lost');
  }
}

class _Unreadable extends FlutterSecureStorage {
  int writes = 0;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw PlatformException(code: 'locked');
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
  }) async {
    writes++;
  }
}
