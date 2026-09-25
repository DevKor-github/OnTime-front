// Invoked only by verify_pair_crash_recovery.py with disposable synthetic data.
// Real host SQLCipher + process death. Disk-backed fixture secure storage and
// injected per-process identity do not establish native mobile plugin behavior.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:uuid/uuid.dart';
import 'package:on_time_front/core/backup/backup_content.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/recovery/encrypted_pair_database.dart';
import 'package:on_time_front/core/database/recovery/pair_files.dart';
import 'package:on_time_front/core/database/recovery/pair_key_store.dart';
import 'package:on_time_front/core/database/recovery/recovery_restore_service.dart';
import 'package:on_time_front/core/database/recovery/store_pair.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  test('real encrypted pair survives killed host process', () async {
    final directory = Directory(Platform.environment['D02_PROBE_DIR']!);
    final point = Platform.environment['D02_PROBE_POINT']!;
    final recovering = Platform.environment['D02_PROBE_MODE'] == 'recover';
    open.overrideForAll(
      () => DynamicLibrary.open(
        Platform.environment['ONTIME_TEST_SQLCIPHER_LIBRARY']!,
      ),
    );
    // This is a Flutter test entrypoint outside test/, with fixture-only prefs.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final identity = const Uuid().v4();
    final files = PairFiles(
      directory,
      PairKeyStore(
        storage: _DiskStorage(File('${directory.path}/fixture-keys.json')),
      ),
      protect: (_) async {},
      checkpoint: (stage) async {
        if (!recovering && stage == point) {
          await File('${directory.path}/cut-ready').writeAsString(
            jsonEncode({'pid': pid, 'identity': identity}),
            flush: true,
          );
          await Completer<void>().future;
        }
      },
    );
    final gate = LocalDataOperationGate();
    final owner = AlarmOperationCoordinator(gate);
    final service = RecoveryRestoreService(
      files,
      gate: gate,
      owner: owner,
      processIdentity: () async => identity,
      cleanupPlatform: () async {},
      repairCutover: () async {},
    );
    if (!recovering) {
      await files
          .database(const StorePair.legacy())
          .writeAsString('synthetic damaged original');
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: 'synthetic recovery sentinel',
        ),
      );
      final content = await BackupContent.capture(
        db,
        cutoff: DateTime.utc(2030),
        sourceAppVersion: 'probe',
        sourcePlatform: 'android',
      );
      await db.close();
      final bytes = await BackupCrypto().encrypt(
        plaintext: Uint8List.fromList(
          utf8.encode(jsonEncode(content.toJson())),
        ),
        password: 'synthetic backup password',
      );
      final candidate = await service.previewBytes(
        bytes,
        'synthetic backup password',
      );
      await service.activate(candidate);
      fail(
        'Expected checkpoint must remain outstanding until controller kills this process',
      );
    } else {
      final old =
          jsonDecode(await File('${directory.path}/cut-ready').readAsString())
              as Map<String, dynamic>;
      expect(pid, isNot(old['pid']));
      expect(identity, isNot(old['identity']));
      expect(await files.database(const StorePair.legacy()).exists(), true);
      if (point == 'manifest.written') {
        await expectLater(
          service.prepareStartup(),
          throwsA(isA<PairRecoveryRequired>()),
        );
        expect(await files.readManifest(), null);
        expect((await service.resume()).followUpPending, false);
      } else {
        await service.prepareStartup();
      }
      final target = await files.selected();
      final db = await openEncryptedPair(files, target);
      expect(
        (await db.select(db.users).getSingle()).note,
        'synthetic recovery sentinel',
      );
      await db.close();
      expect(await files.database(const StorePair.legacy()).exists(), false);
      expect((await files.readRecord())!.stage, PairStage.ready);
      expect(gate.isAvailable, true);
      await File('${directory.path}/verified').writeAsString(
        jsonEncode({
          'oldPid': old['pid'],
          'newPid': pid,
          'ready': true,
          'contentReadBack': true,
          'realSqlCipher': true,
        }),
        flush: true,
      );
    }
  });
}

class _DiskStorage extends FlutterSecureStorage {
  _DiskStorage(this.file);
  final File file;
  Future<Map<String, dynamic>> _all() async => await file.exists()
      ? jsonDecode(await file.readAsString()) as Map<String, dynamic>
      : {};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => (await _all())[key] as String?;
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
    final values = await _all();
    values[key] = value;
    await file.writeAsString(jsonEncode(values), flush: true);
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final values = await _all();
    values.remove(key);
    await file.writeAsString(jsonEncode(values), flush: true);
  }
}
