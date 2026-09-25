import 'recovery/pair_files.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:on_time_front/core/startup/startup_failure.dart';
import 'installation_key_store.dart';
import 'local_data_files_native.dart';

/// Only the first fixed store's creation. D02 extends the evidence resolver
/// before introducing active-pair files; this is not its activation journal.
final class InitialStoreGuard {
  InitialStoreGuard(
    this.file,
    this.keys, {
    Future<void> Function(File)? protect,
    Future<bool> Function()? activationEvidence,
    Future<void> Function(File)? removeCompletedReceipt,
  }) : _protect = protect ?? excludeLocalDatabaseFromPlatformBackup,
       _activationEvidence = activationEvidence,
       _removeCompletedReceipt =
           removeCompletedReceipt ??
           ((file) async {
             await file.delete();
           });
  final File file;
  final InstallationKeyStore keys;
  final Future<void> Function(File) _protect;
  final Future<bool> Function()? _activationEvidence;
  final Future<void> Function(File) _removeCompletedReceipt;
  File get receiptFile => File('${file.path}.creation.json');
  File get temporaryReceipt => File('${receiptFile.path}.tmp');
  static final _openFlights = <String, Future<Uint8List>>{};
  static Future<InitialStoreGuard> device(InstallationKeyStore keys) async =>
      InitialStoreGuard(
        await localDatabaseFile(),
        keys,
        activationEvidence: () async =>
            (await PairFiles.device()).hasEvidence(),
      );

  Future<FileSystemEntityType> _type(String path) =>
      FileSystemEntity.type(path, followLinks: false);
  Future<bool> _exists(String path) async =>
      await _type(path) != FileSystemEntityType.notFound;
  Future<List<String>> _family() async {
    final paths = <String>[];
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final path = '${file.path}$suffix';
      final type = await _type(path);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw const LocalStorePreservationRequired();
      }
      paths.add(path);
    }
    return paths;
  }

  Future<void> requireNoLocalEvidence() async {
    try {
      if ((await _family()).isNotEmpty ||
          await keys.exists() ||
          await _exists(receiptFile.path) ||
          await _exists(temporaryReceipt.path) ||
          await _activationEvidence?.call() == true) {
        throw const LocalStorePreservationRequired();
      }
    } catch (_) {
      throw const LocalStorePreservationRequired();
    }
  }

  Future<_Creation?> _read() async {
    if (!await _exists(receiptFile.path)) {
      if (await _exists(temporaryReceipt.path)) {
        throw const LocalStorePreservationRequired();
      }
      return null;
    }
    if (await _type(receiptFile.path) != FileSystemEntityType.file) {
      throw const LocalStorePreservationRequired();
    }
    try {
      final raw = jsonDecode(await receiptFile.readAsString());
      if (raw is! Map<String, dynamic> ||
          raw.length != 5 ||
          raw['version'] != 1 ||
          raw['store'] != localDatabaseFileName ||
          raw['keySlot'] != 'installation-v1' ||
          raw['owner'] is! String ||
          !RegExp(r'^[a-f0-9-]{36}$').hasMatch(raw['owner'] as String) ||
          !['reserved', 'keyReady', 'verified'].contains(raw['stage'])) {
        throw const LocalStorePreservationRequired();
      }
      return _Creation(raw['owner'] as String, raw['stage'] as String);
    } catch (_) {
      throw const LocalStorePreservationRequired();
    }
  }

  Future<void> _write(_Creation receipt) async {
    await file.parent.create(recursive: true);
    // Parent exclusion also covers SQLite sidecars and interrupted temp writes.
    await _protect(File(file.parent.path));
    if (await _exists(temporaryReceipt.path) &&
        await _type(temporaryReceipt.path) != FileSystemEntityType.file) {
      throw const LocalStorePreservationRequired();
    }
    final value = jsonEncode(receipt.encode());
    await temporaryReceipt.writeAsString(value, flush: true);
    await _protect(temporaryReceipt);
    await temporaryReceipt.rename(receiptFile.path);
    if (await receiptFile.readAsString() != value) {
      throw const LocalStorePreservationRequired();
    }
  }

  Future<Uint8List> prepareOpen() {
    final current = _openFlights[file.path];
    if (current != null) return current;
    return _openFlights[file.path] = _prepare().whenComplete(() {
      _openFlights.remove(file.path);
    });
  }

  Future<Uint8List> _prepare() async {
    try {
      if (await _activationEvidence?.call() == true) {
        throw const LocalStorePreservationRequired();
      }
      final family = await _family();
      final hasMain = family.contains(file.path);
      var receipt = await _read();
      var key = await keys.readExisting();
      if (hasMain) {
        if (key == null ||
            (await file.length() == 0 && receipt?.stage != 'keyReady')) {
          throw const LocalStorePreservationRequired();
        }
        await _protect(file);
        return key;
      }
      if (family.isNotEmpty || receipt?.stage == 'verified') {
        throw const LocalStorePreservationRequired();
      }
      if (receipt == null) {
        if (key != null) throw const LocalStorePreservationRequired();
        // Recheck all observed evidence before claiming this exact namespace.
        await requireNoLocalEvidence();
        receipt = _Creation(const Uuid().v4(), 'reserved');
        await _write(receipt);
      }
      if (key == null) {
        if (receipt.stage != 'reserved') {
          throw const LocalStorePreservationRequired();
        }
        key = await keys.createVerified();
      }
      receipt = _Creation(receipt.owner, 'keyReady');
      await _write(receipt);
      // Never truncate a newly appeared file or treat an unexpected family as
      // ours. The process-level creation flight prevents duplicate app opens.
      if ((await _family()).isNotEmpty) {
        throw const LocalStorePreservationRequired();
      }
      await file.create(exclusive: true);
      await _protect(file);
      return key;
    } catch (_) {
      throw const LocalStorePreservationRequired();
    }
  }

  /// Only this installation's durable initial-creation intent authorizes an
  /// empty schema. Existing version-zero files do not grant their own authority.
  Future<bool> allowsSchemaCreation() async =>
      (await _read())?.stage == 'keyReady';

  /// Called only after SQLCipher, schema migration and identity read succeeded.
  /// A failed final unlink leaves the same pair and owned receipt for retry.
  Future<void> completeVerifiedCreation() async {
    final receipt = await _read();
    if (receipt == null) return;
    if (!await file.exists() ||
        await file.length() == 0 ||
        await keys.readExisting() == null) {
      throw const LocalStorePreservationRequired();
    }
    await _write(_Creation(receipt.owner, 'verified'));
    await _removeCompletedReceipt(receiptFile);
    if (await _exists(receiptFile.path) ||
        await _exists(temporaryReceipt.path)) {
      throw const LocalStorePreservationRequired();
    }
  }

  static Future<void> removeDeviceReceipt() async =>
      (await device(InstallationKeyStore())).removeReceipt();

  Future<void> removeReceipt() async {
    for (final suffix in ['.creation.json', '.creation.json.tmp']) {
      final path = '${file.path}$suffix';
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.directory) {
        throw const LocalStorePreservationRequired();
      }
      if (type == FileSystemEntityType.link) {
        await Link(path).delete();
      } else {
        await File(path).delete();
      }
      if (await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const LocalStorePreservationRequired();
      }
    }
  }
}

final class _Creation {
  const _Creation(this.owner, this.stage);
  final String owner;
  final String stage;
  Map<String, Object> encode() => {
    'version': 1,
    'store': localDatabaseFileName,
    'keySlot': 'installation-v1',
    'owner': owner,
    'stage': stage,
  };
}
