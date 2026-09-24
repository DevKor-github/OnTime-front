import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'alarm_ownership_journal.dart';

/// Atomic replacement on the same filesystem. Flush/read-back is not a claim
/// about directory fsync, sudden power failure, or physical forensic erasure.
final class FileAlarmJournalStore implements RecoverableAlarmJournalStore {
  FileAlarmJournalStore(
    this.directory, {
    this.excludeFromBackup,
    this.checkpoint,
  });
  final Future<Directory> Function() directory;
  final Future<void> Function(String)? excludeFromBackup;
  final Future<void> Function(String)? checkpoint;

  Future<File> _file() async {
    final dir = await directory();
    await dir.create(recursive: true);
    await excludeFromBackup?.call(dir.path);
    return File(p.join(dir.path, 'ownership-v1.json'));
  }

  Future<String> _readText(File file) async {
    try {
      return utf8.decode(await file.readAsBytes());
    } on FormatException {
      // FileSystemException deliberately propagates: a transient read failure
      // is not evidence that the bytes may be quarantined or replaced.
      throw const AlarmJournalCorrupt();
    }
  }

  Future<List<File>> _quarantines(File file) async => [
    await for (final entry in file.parent.list())
      if (entry is File && entry.path.startsWith('${file.path}.corrupt.'))
        entry,
  ];

  @override
  Future<String?> read() async {
    final file = await _file();
    if (await File('${file.path}.recovering').exists()) {
      throw const AlarmJournalCorrupt();
    }
    if (await file.exists()) return _readText(file);
    // A valid staged first generation may be promoted. Truncated first writes
    // require reconstruction from registry/provider evidence under the owner.
    final staged = File('${file.path}.pending');
    if (await staged.exists()) {
      final raw = await _readText(staged);
      AlarmJournalSnapshot.decode(raw);
      await staged.rename(file.path);
      if (await _readText(file) != raw) {
        throw const AlarmJournalUnavailable();
      }
      return raw;
    }
    if ((await _quarantines(file)).isNotEmpty) {
      // A process may have died after quarantining but before publishing the
      // reconstructed journal. This is never a clean/new installation.
      throw const AlarmJournalCorrupt();
    }
    return null;
  }

  @override
  Future<void> recoverCorrupt(String value) async {
    AlarmJournalSnapshot.decode(value);
    final file = await _file();
    final staged = File('${file.path}.pending');
    final recovering = File('${file.path}.recovering');
    var corrupt =
        await recovering.exists() ||
        (!await file.exists() && (await _quarantines(file)).isNotEmpty);
    // Validate every live candidate before moving anything. A newer version or
    // valid JSON with impossible semantics is not an automatic repair target.
    for (final candidate in [file, staged]) {
      if (!await candidate.exists()) continue;
      try {
        AlarmJournalSnapshot.decode(await _readText(candidate));
      } on AlarmJournalCorrupt {
        corrupt = true;
      }
    }
    if (!corrupt) throw const AlarmJournalUnavailable();

    await recovering.writeAsString('syntax-recovery-v1', flush: true);
    if (await _readText(recovering) != 'syntax-recovery-v1') {
      throw const AlarmJournalUnavailable();
    }
    await checkpoint?.call('recoveryMarked');
    for (final candidate in [file, staged]) {
      if (!await candidate.exists()) continue;
      var suffix = 0;
      while (await File('${file.path}.corrupt.$suffix').exists()) {
        suffix++;
      }
      await candidate.rename('${file.path}.corrupt.$suffix');
      await checkpoint?.call(
        identical(candidate, file) ? 'quarantinedMain' : 'quarantinedPending',
      );
    }
    await write(value);
    if (await _readText(file) != value) throw const AlarmJournalUnavailable();
    await checkpoint?.call('recoveryVerified');
    await recovering.delete();
    await checkpoint?.call('recoveryPublished');
    if (await recovering.exists() || await read() != value) {
      throw const AlarmJournalUnavailable();
    }
  }

  @override
  Future<void> write(String value) async {
    final file = await _file();
    final temp = File('${file.path}.pending');
    if (await temp.exists()) {
      try {
        AlarmJournalSnapshot.decode(await _readText(temp));
      } on AlarmJournalCorrupt {
        // An incomplete next generation never authorized an OS side effect.
        // Only a verified committed generation makes replacing that stage safe.
        if (!await file.exists()) rethrow;
        AlarmJournalSnapshot.decode(await _readText(file));
      }
      // Unsupported versions and invalid semantic states propagate unchanged;
      // an older committed file is not permission to overwrite a future stage.
    }
    await temp.writeAsString(value, flush: true);
    await checkpoint?.call('written');
    if (await temp.readAsString() != value) {
      throw const AlarmJournalUnavailable();
    }
    await checkpoint?.call('verified');
    await temp.rename(file.path);
    await checkpoint?.call('renamed');
    if (await file.readAsString() != value) {
      throw const AlarmJournalUnavailable();
    }
    await checkpoint?.call('readBack');
  }

  @override
  Future<void> remove() async {
    final file = await _file();
    final temp = File('${file.path}.pending');
    // Called only for a verified complete reset. Remove retained corruption
    // before the complete receipt; a failed unlink cannot look like new state.
    for (final quarantine in await _quarantines(file)) {
      await quarantine.delete();
    }
    final recovering = File('${file.path}.recovering');
    if (await recovering.exists()) await recovering.delete();
    if (await temp.exists()) await temp.delete();
    if (await file.exists()) await file.delete();
    await checkpoint?.call('removed');
    if (await file.exists()) throw const AlarmJournalUnavailable();
  }
}

AlarmJournalStore createProductAlarmJournalStore() => FileAlarmJournalStore(
  () async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'delivery-ownership'),
  ),
  excludeFromBackup: (path) async {
    // Android root/file exclusions already cover application support, including
    // cloud and device-transfer. iOS excludes this entire independent directory.
    if (Platform.isIOS) {
      await const MethodChannel(
        'on_time_front/native_alarm',
      ).invokeMethod<void>('excludeFromBackup', {'path': path});
    }
  },
);
