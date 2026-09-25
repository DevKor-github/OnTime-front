import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:on_time_front/core/backup/restore_staging.dart';
import 'package:on_time_front/core/database/database.dart';

/// Unit/workflow fixtures exercise materialization/read-back with real SQLite.
/// This explicit injected adapter is not encrypted staging evidence.
Future<RestoreStaging> memoryRestoreStaging() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final stage = RestoreStaging(db, db.close);
  addTearDown(stage.release);
  return stage;
}

Future<void> noPlatformRestoreCleanup() async {}

Future<BackupIngestionStore> memoryBackupIngestion(BackupBudget budget) async {
  final store = BackupIngestionStore.memoryForTesting(budget);
  addTearDown(store.release);
  return store;
}

BackupProcessingOwner testBackupProcessingOwner() => BackupProcessingOwner();
