import 'backup_private_files.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/core/database/sqlcipher_loader.dart';
import 'dart:io';
import 'dart:math';
import 'package:drift/native.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_files.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

typedef RestoreStagingFactory = Future<RestoreStaging> Function();

/// Actual SQLCipher staging, never a plaintext SQLite fallback. Temporary keys
/// live only in the owner; the installation secure-storage key is untouched.
final class RestoreStaging {
  RestoreStaging(this.database, this._release);
  final AppDatabase database;
  final Future<void> Function() _release;
  bool _released = false;
  static final _live = BackupPrivateFiles.livePaths;
  static Future<Directory> directory() async => Directory(
    p.join(
      (await getApplicationSupportDirectory()).path,
      'ontime_restore_staging',
    ),
  );

  static Future<void> cleanupAbandoned({Directory? root}) async {
    root ??= await directory();
    if (!await root.exists()) return;
    await for (final entry in root.list(followLinks: false)) {
      if (_live.any(
        (path) => entry.path == path || entry.path.startsWith('$path-'),
      )) {
        continue;
      }
      // Never follow a link out of our private staging namespace.
      await entry.delete(recursive: true);
    }
  }

  static Future<RestoreStaging> create({
    Directory? root,
    Future<void> Function(File)? removeFile,
    String? attemptId,
  }) async {
    configureSqlCipherLoader();
    root ??= await directory();
    await root.create(recursive: true);
    final id = attemptId ?? const Uuid().v4();
    if (!RegExp(r'^[a-zA-Z0-9-]{1,64}$').hasMatch(id)) {
      throw ArgumentError('Invalid attempt identity');
    }
    final file = File(p.join(root.path, '$id.sqlite'));
    if (!_live.add(file.path)) throw StateError('Attempt already owned');
    var created = false;
    AppDatabase? db;
    Future<void> remove() async {
      if (!created) {
        _live.remove(file.path);
        return;
      }
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final member = File('${file.path}$suffix');
        if (await member.exists()) {
          if (removeFile != null) {
            await removeFile(member);
          } else {
            await member.delete();
          }
        }
        if (await member.exists()) {
          throw StateError('Staging cleanup unconfirmed');
        }
      }
      _live.remove(file.path);
    }

    Future<void> cleanupOwned() async {
      await db?.close();
      db = null;
      await remove();
    }

    try {
      await file.create(exclusive: true);
      created = true;
      await excludeLocalDatabaseFromPlatformBackup(file);
      // Excluding the directory covers sidecars created by SQLite later.
      await excludeLocalDatabaseFromPlatformBackup(File(root.path));
      final random = Random.secure();
      final key = List<int>.generate(32, (_) => random.nextInt(256));
      final hex = key.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
      db = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) {
            guardEncryptedDatabase(
              raw,
              hex,
              role: DatabaseOpenRole.ownedCreation,
              allowCreation: true,
            );
          },
        ),
      );
      await db!.customSelect('SELECT 1').get();
      return RestoreStaging(db!, cleanupOwned);
    } catch (original) {
      try {
        await cleanupOwned();
      } catch (cleanup) {
        throw RestoreStagingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
          retryCleanup: cleanupOwned,
        );
      }
      rethrow;
    }
  }

  Future<void> release() async {
    if (_released) return;
    try {
      await _release();
      _released = true;
    } catch (error) {
      throw RestoreStagingCleanupFailure(cleanupError: error);
    }
  }
}
