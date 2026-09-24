import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import '../../helpers/noop_alarm_cleanup.dart';
import '../../helpers/sodium_test_loader.dart';

class _Metadata implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async =>
      const AppMetadata(version: '1', buildNumber: '1');
}

class _Cleanup extends NoopAlarmCleanup {
  int calls = 0;
  @override
  Future<void> forDataReplacement() async {
    calls++;
  }
}

void main() {
  test(
    'preview followed by a durable edit never overwrites that edit',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final gate = LocalDataOperationGate();
      final cleanup = _Cleanup();
      addTearDown(db.close);
      addTearDown(gate.dispose);
      await db.userDao.putUser(
        const UserEntity(
          id: 'local-profile',
          spareTime: Duration.zero,
          note: 'original',
        ),
      );
      final service = BackupService(
        db,
        _Metadata(),
        cleanup,
        operationGate: gate,
        crypto: BackupCrypto(sodiumLoader: loadSodiumForTest),
      );
      const password = 'synthetic backup password';
      final preview = await service.previewEncryptedBackup(
        await service.createEncryptedBackup(password),
        password,
      );
      await db.userDao.updateSpareTime(
        'local-profile',
        const Duration(minutes: 17),
      );
      Object? failure;
      try {
        await service.applyRestore(preview);
      } catch (error) {
        failure = error;
      }
      expect((await db.select(db.users).getSingle()).spareTime, 17);
      expect(failure, isNotNull);
      expect(cleanup.calls, 0);
      expect(gate.generation, 0);
    },
  );
}
