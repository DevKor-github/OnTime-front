import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../local_data_files_native.dart';
import 'pair_key_store.dart';
import 'store_pair.dart';

/// Fixed installation namespaces. A backup can never name a path or key slot.
/// Flush + rename + read-back provides process-restart evidence, not a promise
/// of directory fsync or power-loss durability.
final class PairFiles {
  PairFiles(
    this.support,
    this.keys, {
    Future<void> Function(File)? protect,
    this.checkpoint,
  }) : protect = protect ?? excludeLocalDatabaseFromPlatformBackup;
  final Directory support;
  final PairKeyStore keys;
  final Future<void> Function(File) protect;
  final Future<void> Function(String)? checkpoint;
  static Future<PairFiles> device() async =>
      PairFiles(await getApplicationSupportDirectory(), PairKeyStore());
  Directory get metadata =>
      Directory(p.join(support.path, 'ontime_pair_state'));
  Directory get pairs =>
      Directory(p.join(support.path, 'ontime_recovery_pairs'));
  File get manifest => File(p.join(metadata.path, 'active-v1.json'));
  File get record => File(p.join(metadata.path, 'activation-v1.json'));
  File database(StorePair pair) => File(
    pair.isLegacy
        ? p.join(support.path, localDatabaseFileName)
        : p.join(pairs.path, '${pair.id}.sqlite'),
  );
  Future<bool> exists(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.notFound;
  Future<void> checkNamespaces() async {
    for (final dir in [metadata, pairs]) {
      final type = await FileSystemEntity.type(dir.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw const PairAuthorityUnavailable();
      }
    }
  }

  Future<void> regular(String path) async {
    await checkNamespaces();
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const PairAuthorityUnavailable();
    }
  }

  Future<void> prepareDirectories() async {
    for (final dir in [support, metadata, pairs]) {
      final type = await FileSystemEntity.type(dir.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw const PairAuthorityUnavailable();
      }
      await dir.create(recursive: true);
      await protect(File(dir.path));
    }
  }

  Future<String?> _text(File file) async {
    await regular(file.path);
    if (!await file.exists()) return null;
    if (await file.length() > 16384) throw const PairAuthorityUnavailable();
    return file.readAsString();
  }

  Future<StorePair?> readManifest() async {
    final text = await _text(manifest);
    if (text == null) return null;
    try {
      final raw = jsonDecode(text);
      if (raw is! Map<String, dynamic> ||
          raw.length != 2 ||
          raw['version'] != 1) {
        throw const PairAuthorityUnavailable();
      }
      final pair = StorePair.decode(raw['pair']);
      if (pair.isLegacy) throw const PairAuthorityUnavailable();
      return pair;
    } catch (_) {
      throw const PairAuthorityUnavailable();
    }
  }

  Future<PairRecord?> readRecord() async {
    final text = await _text(record);
    final staged = await _text(File('${record.path}.pending'));
    if (text == null) {
      // A reserved first record is safe to publish: it precedes key/file effects.
      if (staged == null) return null;
      final pending = PairRecord.decode(jsonDecode(staged));
      if (pending.stage != PairStage.reserved) {
        throw const PairAuthorityUnavailable();
      }
      await File('${record.path}.pending').rename(record.path);
      if (await _text(record) != staged) throw const PairAuthorityUnavailable();
      return pending;
    }
    final value = PairRecord.decode(jsonDecode(text));
    if (staged != null) {
      final pending = PairRecord.decode(jsonDecode(staged));
      final replacingFinished =
          (value.stage == PairStage.ready ||
              value.stage == PairStage.cancelled) &&
          pending.stage == PairStage.reserved &&
          pending.original ==
              (value.stage == PairStage.ready ? value.target : value.original);
      if (!replacingFinished &&
          (pending.target != value.target ||
              pending.original != value.original ||
              pending.originProcess != value.originProcess ||
              pending.stage.index < value.stage.index)) {
        throw const PairAuthorityUnavailable();
      }
      // Only the committed record authorized side effects. Never promote later
      // intent/verification based solely on a valid pending JSON write.
    }
    return value;
  }

  Future<void> _write(File file, String value, String name) async {
    await prepareDirectories();
    await regular(file.path);
    final pending = File('${file.path}.pending');
    await regular(pending.path);
    await pending.writeAsString(value, flush: true);
    await protect(pending);
    await checkpoint?.call('$name.written');
    if (await _text(pending) != value) throw const PairAuthorityUnavailable();
    await pending.rename(file.path);
    await checkpoint?.call('$name.renamed');
    if (await _text(file) != value) throw const PairAuthorityUnavailable();
    await checkpoint?.call('$name.readBack');
  }

  Future<void> writeRecord(PairRecord value) async {
    await readRecord(); // Do not overwrite unreadable/future authority.
    await _write(
      record,
      jsonEncode(value.encode()),
      'record.${value.stage.name}',
    );
  }

  String manifestBytes(StorePair value) =>
      jsonEncode({'version': 1, 'pair': value.id});
  Future<void> publish(StorePair value, {StorePair? expected}) async {
    final current = await readManifest();
    if (current != expected && current != value) {
      throw const PairAuthorityUnavailable();
    }
    final pending = await _text(File('${manifest.path}.pending'));
    if (pending != null && pending != manifestBytes(value)) {
      throw const PairAuthorityUnavailable();
    }
    await _write(manifest, manifestBytes(value), 'manifest');
  }

  Future<void> requireExisting(StorePair pair) async {
    final file = database(pair);
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      await regular('${file.path}$suffix');
    }
    if (!await file.exists() || await file.length() == 0) {
      throw const PairAuthorityUnavailable();
    }
  }

  Future<void> checkIntent(
    PairRecord value, {
    bool forAbort = false,
    bool firstActivation = false,
  }) async {
    final current = await readRecord();
    if (current == null ||
        jsonEncode(current.encode()) != jsonEncode(value.encode())) {
      throw const PairAuthorityUnavailable();
    }
    final staged = await _text(File('${record.path}.pending'));
    if (staged != null) {
      final next = PairRecord.decode(jsonDecode(staged));
      if (firstActivation && next.stage != PairStage.confirmed) {
        throw const PairAuthorityUnavailable();
      }
      if (next.target != value.target ||
          next.original != value.original ||
          next.originProcess != value.originProcess ||
          next.originalEvidence != value.originalEvidence ||
          next.runtimeIdentity != value.runtimeIdentity ||
          (forAbort &&
              next.stage != PairStage.confirmed &&
              next.stage != PairStage.aborting &&
              !(value.stage == PairStage.aborting &&
                  next.stage == PairStage.cancelled))) {
        throw const PairAuthorityUnavailable();
      }
    }
    final pending = await _text(File('${manifest.path}.pending'));
    if (pending != null && pending != manifestBytes(value.target)) {
      throw const PairAuthorityUnavailable();
    }
    if (await exists(resetCompletion.path) ||
        await exists('${resetCompletion.path}.pending')) {
      throw const PairAuthorityUnavailable();
    }
    await checkNamespaces();
    if (await pairs.exists()) {
      final names = <String>{
        for (final pair in [value.original, value.target])
          if (!pair.isLegacy)
            for (final suffix in ['', '-wal', '-shm', '-journal'])
              '${pair.id}.sqlite$suffix',
      };
      await for (final entry in pairs.list(followLinks: false)) {
        if (!names.contains(p.basename(entry.path))) {
          throw const PairAuthorityUnavailable();
        }
        await regular(entry.path);
      }
    }
  }

  Future<void> removeOwnedPublication(PairRecord value) async {
    await checkIntent(value, forAbort: true);
    final pending = File('${manifest.path}.pending');
    if (await pending.exists()) await pending.delete();
    if (await exists(pending.path)) throw const PairAuthorityUnavailable();
    await checkpoint?.call('abort.manifestPending.removed');
  }

  Future<bool> hasEvidence() async {
    if (await keys.hasHistory()) return true;
    for (final dir in [metadata, pairs]) {
      final type = await FileSystemEntity.type(dir.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.directory) {
        throw const PairAuthorityUnavailable();
      }
      if (!await dir.list(followLinks: false).isEmpty) return true;
    }
    return false;
  }

  Future<StorePair> selected() async {
    if (await exists(resetCompletion.path) ||
        await exists('${resetCompletion.path}.pending')) {
      throw const PairAuthorityUnavailable();
    }
    final selected = await readManifest();
    final pending = await _text(File('${manifest.path}.pending'));
    if (pending != null &&
        (selected == null || pending != manifestBytes(selected))) {
      throw const PairAuthorityUnavailable();
    }
    final state = await readRecord();
    if (selected != null) {
      if (state == null ||
          (selected != state.target && selected != state.original) ||
          (selected == state.target && !state.confirmed)) {
        throw const PairAuthorityUnavailable();
      }
      return selected;
    }
    if (state != null &&
        !state.confirmed &&
        state.original.isLegacy &&
        !await keys.hasHistory()) {
      return state
          .original; // Explicit unconfirmed reservation lineage, no activation.
    }
    if (await hasEvidence()) throw const PairAuthorityUnavailable();
    return const StorePair.legacy();
  }

  /// Encrypted bytes and opaque slot value are hashed only as bounded local
  /// currentness evidence. No plaintext/secret is written into metadata.
  Future<String> evidence(StorePair pair) async {
    final values = <String>[];
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('${database(pair).path}$suffix');
      await regular(file.path);
      values.add(
        await file.exists()
            ? '$suffix:${await sha256.bind(file.openRead()).first}'
            : '$suffix:absent',
      );
    }
    values.add(
      'key:${sha256.convert(utf8.encode(await keys.raw(pair) ?? 'absent'))}',
    );
    return sha256.convert(utf8.encode(values.join('|'))).toString();
  }

  Future<void> removeFamily(StorePair pair) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('${database(pair).path}$suffix');
      await regular(file.path);
      if (await file.exists()) await file.delete();
      if (await exists(file.path)) throw const PairAuthorityUnavailable();
      await checkpoint?.call('family.$suffix.removed');
    }
  }

  Future<void> removeRecord() async {
    for (final file in [File('${record.path}.pending'), record]) {
      await regular(file.path);
      if (await file.exists()) await file.delete();
      if (await exists(file.path)) throw const PairAuthorityUnavailable();
    }
  }

  File get resetCompletion => File(p.join(metadata.path, 'reset-keys-v1.json'));
  Future<Set<StorePair>?> _resetSlots() async {
    final text = await _text(resetCompletion);
    final pending = await _text(File('${resetCompletion.path}.pending'));
    Set<StorePair> parse(String value) {
      try {
        final raw = jsonDecode(value);
        if (raw is! Map<String, dynamic> ||
            raw.length != 2 ||
            raw['version'] != 1 ||
            raw['slots'] is! List) {
          throw const PairAuthorityUnavailable();
        }
        final list = (raw['slots'] as List).map(StorePair.decode).toList();
        final slots = list.toSet();
        if (list.isEmpty ||
            list.length > 3 ||
            slots.length != list.length ||
            !slots.contains(const StorePair.legacy())) {
          throw const PairAuthorityUnavailable();
        }
        return slots;
      } catch (_) {
        throw const PairAuthorityUnavailable();
      }
    }

    final staged = pending == null ? null : parse(pending);
    if (text == null) {
      if (staged != null) {
        final state = await readRecord();
        final expected = {
          const StorePair.legacy(),
          if (state != null) state.target,
          if (state != null) state.original,
        };
        if (staged.length != expected.length || !staged.containsAll(expected)) {
          throw const PairAuthorityUnavailable();
        }
      }
      return null; // No metadata was removed before receipt rename/read-back.
    }
    final slots = parse(text);
    final state = await readRecord();
    final active = await readManifest();
    if (state != null) {
      final owned = {const StorePair.legacy(), state.target, state.original};
      if (slots.length != owned.length || !slots.containsAll(owned)) {
        throw const PairAuthorityUnavailable();
      }
    }
    if (active != null && !slots.contains(active)) {
      throw const PairAuthorityUnavailable();
    }
    if (staged != null &&
        (staged.length != slots.length || !staged.containsAll(slots))) {
      throw const PairAuthorityUnavailable();
    }
    return slots;
  }

  Future<Set<StorePair>> inventory() async {
    final completing = await _resetSlots();
    if (completing != null) return completing;
    final state = await readRecord();
    final active = await readManifest();
    if (state == null && (active != null || await hasEvidence())) {
      throw const PairAuthorityUnavailable();
    }
    if (state != null &&
        active != null &&
        active != state.target &&
        active != state.original) {
      throw const PairAuthorityUnavailable();
    }
    return {
      const StorePair.legacy(),
      if (state != null) state.target,
      if (state != null) state.original,
      ?active,
    };
  }

  /// Called only by D03 after explicit reset intent is persisted. Retain record
  /// and manifest until the separate key stage has confirmed all slot removals.
  Future<void> resetFiles() async {
    for (final pair in await inventory()) {
      await removeFamily(pair);
    }
  }

  Future<void> resetKeysAndMetadata() async {
    final pairs = await inventory();
    for (final pair in pairs) {
      await keys.remove(pair);
    }
    for (final pair in pairs) {
      if (await keys.raw(pair) != null) throw const PairAuthorityUnavailable();
    }
    // A reset-specific slot receipt survives metadata removal. Only D03's
    // persisted reset intent calls these methods; normal selection never trusts
    // this receipt to create a new store.
    await _write(
      resetCompletion,
      jsonEncode({'version': 1, 'slots': pairs.map((p) => p.id).toList()}),
      'resetKeys',
    );
    // Keep an independent history witness until all metadata is removed.
    for (final file in [
      File('${manifest.path}.pending'),
      manifest,
      File('${record.path}.pending'),
      record,
    ]) {
      await regular(file.path);
      if (await file.exists()) await file.delete();
      if (await exists(file.path)) throw const PairAuthorityUnavailable();
      await checkpoint?.call('resetMetadata.${p.basename(file.path)}.removed');
    }
    await keys.removeHistory();
    await checkpoint?.call('resetHistory.removed');
    for (final file in [
      File('${resetCompletion.path}.pending'),
      resetCompletion,
    ]) {
      await regular(file.path);
      if (await file.exists()) await file.delete();
      if (await exists(file.path)) throw const PairAuthorityUnavailable();
    }
  }
}
