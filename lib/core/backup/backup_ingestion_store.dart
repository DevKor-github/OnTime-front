import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:uuid/uuid.dart';
import 'package:on_time_front/core/database/local_data_files.dart';
import 'package:on_time_front/core/database/sqlcipher_loader.dart';
import 'package:on_time_front/core/database/encrypted_database_guard.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'backup_private_files.dart';
import 'backup_json_reader.dart';
import 'backup_limits.dart';
import 'restore_staging.dart';

/// Scalar replacement authorized by the authenticated time-review owner.
/// The expected value and existence bind it to the exact candidate revision.
class BackupTimeScalarEdit {
  const BackupTimeScalarEdit({
    required this.parent,
    required this.field,
    required this.expectedExists,
    required this.expectedValue,
    required this.value,
  });
  final int parent;
  final String field;
  final bool expectedExists;
  final Object? expectedValue;
  final Object value;
}

/// A core-produced finite recurrence patch, not a client JSON editing API.
class BackupRecurringScalarEdit {
  const BackupRecurringScalarEdit({
    required this.kind,
    required this.identity,
    required this.parent,
    required this.field,
    required this.expectedExists,
    required this.expectedValue,
    required this.value,
  });
  final String kind;
  final String identity;
  final int parent;
  final String field;
  final bool expectedExists;
  final Object? expectedValue;
  final Object? value;
}

/// Private provisional JSON graph, not an AppDatabase or portable schema.
/// Only an owned fresh file may be created. It has no activation authority.
class BackupIngestionStore implements BackupJsonSink {
  BackupIngestionStore._(this._db, this._remove, this.budget) {
    _db.execute('''CREATE TABLE nodes (
      id INTEGER PRIMARY KEY, parent INTEGER, key TEXT, kind TEXT NOT NULL,
      value TEXT, UNIQUE(parent,key))''');
    _db.execute('CREATE INDEX node_parent_order ON nodes(parent,id)');
    _db.execute('''CREATE TABLE original_time_fields (
      parent INTEGER NOT NULL, field TEXT NOT NULL, existed INTEGER NOT NULL,
      kind TEXT, value TEXT, PRIMARY KEY(parent,field))''');
    _db.execute('''CREATE TABLE records (
      kind TEXT NOT NULL, identity TEXT NOT NULL, node INTEGER NOT NULL,
      owner TEXT, reference TEXT, slot TEXT, ordinal INTEGER, position INTEGER,
      detail TEXT, PRIMARY KEY(kind,identity))''');
    _db.execute('CREATE INDEX record_owner ON records(kind,owner,position)');
    _db.execute('CREATE INDEX record_node ON records(kind,node)');
    _db.execute(
      "CREATE UNIQUE INDEX occurrence_ordinal ON records(reference,ordinal) WHERE kind='occurrence'",
    );
    _db.execute(
      'CREATE UNIQUE INDEX record_slot ON records(kind,reference,slot) WHERE slot IS NOT NULL',
    );
    _db.execute('PRAGMA application_id=1330922057');
    _db.userVersion = 1;
    _insert = _db.prepare(
      'INSERT INTO nodes(parent,key,kind,value) VALUES(?,?,?,?)',
    );
    _db.execute('BEGIN');
  }
  final sql.Database _db;
  final Future<void> Function() _remove;
  final BackupBudget budget;
  late final sql.PreparedStatement _insert;
  int _pending = 0;
  bool _writing = true;
  bool _recordTransaction = false;
  int _recordPending = 0;
  bool _closed = false;
  bool _statementClosed = false;
  bool _released = false;

  /// Deliberately explicit plaintext in-memory test adapter; not cipher proof.
  factory BackupIngestionStore.memoryForTesting(
    BackupBudget budget, {
    Future<void> Function()? onRelease,
  }) => BackupIngestionStore._(
    sql.sqlite3.openInMemory(),
    onRelease ?? () async {},
    budget,
  );

  static Future<BackupIngestionStore> create(
    BackupBudget budget, {
    Directory? root,
    String? attemptId,
  }) async {
    configureSqlCipherLoader();
    root ??= await RestoreStaging.directory();
    await root.create(recursive: true);
    final id = attemptId ?? const Uuid().v4();
    if (!RegExp(r'^[a-zA-Z0-9-]{1,64}$').hasMatch(id)) {
      throw ArgumentError('Invalid attempt identity');
    }
    final file = File(p.join(root.path, '$id.ingestion.sqlite'));
    // Reserve ownership before the first asynchronous file creation. A concurrent
    // abandoned-file sweep must never mistake our pending creation for an orphan.
    if (!BackupPrivateFiles.livePaths.add(file.path)) {
      throw StateError('Attempt already owned');
    }
    var created = false;
    final key = Uint8List.fromList(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    );
    sql.Database? raw;
    Future<void> remove() async {
      if (!created) {
        BackupPrivateFiles.livePaths.remove(file.path);
        return;
      }
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final member = File('${file.path}$suffix');
        if (await member.exists()) await member.delete();
        if (await member.exists()) {
          throw StateError('Encrypted ingestion cleanup unconfirmed');
        }
      }
      BackupPrivateFiles.livePaths.remove(file.path);
    }

    try {
      await file.create(exclusive: true);
      created = true;
      await excludeLocalDatabaseFromPlatformBackup(file);
      await excludeLocalDatabaseFromPlatformBackup(File(root.path));
      raw = sql.sqlite3.open(file.path);
      final capability = raw.select('PRAGMA cipher_version');
      if (capability.length != 1 ||
          capability.single.values.single is! String ||
          (capability.single.values.single as String).isEmpty) {
        throw const EncryptedDatabaseUnavailable();
      }
      final hex = key.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
      raw.execute('PRAGMA key = "x\'$hex\'"');
      // This narrow fresh-file contract does not disable the active schema guard.
      if (raw.userVersion != 0 ||
          raw
              .select(
                "SELECT name FROM sqlite_master WHERE name NOT GLOB 'sqlite_*'",
              )
              .isNotEmpty) {
        throw const EncryptedDatabaseUnavailable();
      }
      raw.execute('PRAGMA cipher_memory_security=ON');
      raw.execute('PRAGMA temp_store=MEMORY');
      final store = BackupIngestionStore._(raw, remove, budget);
      // Force actual encrypted/keyed reads before accepting provisional content.
      raw.select('SELECT count(*) FROM nodes');
      return store;
    } catch (original) {
      Future<void> cleanupOwned() async {
        if (raw != null) {
          raw!.dispose();
          raw = null;
        }
        await remove();
      }

      try {
        await cleanupOwned();
      } catch (cleanup) {
        budget.lease?.retainCleanup(cleanupOwned);
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  @override
  int writeNode(int? parent, String? key, String kind, Object? value) {
    if (!_writing || _closed) throw StateError('Ingestion writer closed');
    try {
      _insert.execute([
        parent,
        key,
        kind,
        value == null
            ? null
            : value is String
            ? value
            : jsonEncode(value),
      ]);
    } on sql.SqliteException catch (error) {
      if (error.resultCode == 19) BackupLimits.invalid();
      rethrow;
    }
    final id = _db.lastInsertRowId;
    if (++_pending == 256) {
      _db.execute('COMMIT');
      _db.execute('BEGIN');
      _pending = 0;
    }
    return id;
  }

  void finish() {
    if (_writing) {
      _db.execute('COMMIT');
      _writing = false;
    }
    if (_db.select('PRAGMA quick_check').single.values.single != 'ok') {
      BackupLimits.invalid();
    }
  }

  Map<String, Object?> node(int id) {
    budget.visit();
    final rows = _db.select('SELECT * FROM nodes WHERE id=?', [id]);
    if (rows.length != 1) BackupLimits.invalid();
    return rows.single;
  }

  int? child(int parent, String key) {
    budget.visit();
    final rows = _db.select('SELECT id FROM nodes WHERE parent=? AND key=?', [
      parent,
      key,
    ]);
    return rows.isEmpty ? null : rows.single['id'] as int;
  }

  Iterable<Map<String, Object?>> children(int parent) sync* {
    var after = 0;
    while (true) {
      final batch = _db.select(
        'SELECT id,parent,key,kind FROM nodes WHERE parent=? AND id>? ORDER BY id LIMIT 128',
        [parent, after],
      );
      if (batch.isEmpty) return;
      for (final row in batch) {
        budget.visit();
        after = row['id'] as int;
        yield row;
      }
    }
  }

  Object? scalar(int id) {
    final row = node(id);
    if (row['kind'] == 'object' || row['kind'] == 'array') {
      BackupLimits.invalid();
    }
    return row['kind'] == 'string'
        ? row['value']
        : row['value'] == null
        ? null
        : jsonDecode(row['value'] as String);
  }

  /// Only explicitly requested fields are decoded. Unknown subtrees have been
  /// bounded and duplicate-checked during parsing, but never reassembled here.
  Map<String, dynamic> fields(int id, Set<String> fields) {
    if (node(id)['kind'] != 'object') BackupLimits.invalid();
    if (fields.isEmpty) return {};
    // The schema supplies this fixed small field list. A wide unknown object
    // does not become a wide result or an in-memory key set here.
    final rows = _db.select(
      'SELECT key,kind,value FROM nodes WHERE parent=? AND key IN (${List.filled(fields.length, '?').join(',')})',
      [id, ...fields],
    );
    budget.visit(rows.length);
    final result = <String, dynamic>{};
    for (final row in rows) {
      if (row['kind'] == 'array' || row['kind'] == 'object') {
        BackupLimits.invalid();
      }
      result[row['key'] as String] = row['kind'] == 'string'
          ? row['value']
          : row['value'] == null
          ? null
          : jsonDecode(row['value'] as String);
    }
    return result;
  }

  int requiredChild(int parent, String key, String kind) {
    final id = child(parent, key);
    if (id == null || node(id)['kind'] != kind) BackupLimits.invalid();
    return id;
  }

  /// Disk-indexed identities and relations. Duplicate identities never replace
  /// earlier records, even if the apparent payloads happen to be equal.
  void addRecord(
    String kind,
    String identity,
    int node, {
    String? owner,
    String? reference,
    String? slot,
    int? ordinal,
    int? position,
    String? detail,
  }) {
    budget.visit();
    try {
      _db.execute(
        'INSERT INTO records(kind,identity,node,owner,reference,slot,ordinal,position,detail) VALUES(?,?,?,?,?,?,?,?,?)',
        [
          kind,
          identity,
          node,
          owner,
          reference,
          slot,
          ordinal,
          position,
          detail,
        ],
      );
    } on sql.SqliteException catch (error) {
      if (error.resultCode == 19) BackupLimits.invalid();
      rethrow;
    }
    if (_recordTransaction && ++_recordPending == 256) {
      _db.execute('COMMIT');
      _recordTransaction = false;
      _db.execute('BEGIN');
      _recordTransaction = true;
      _recordPending = 0;
    }
  }

  Future<void> validateRecords(Future<void> Function() validate) async {
    if (_writing || _closed || _recordTransaction) {
      throw StateError('Invalid validation phase');
    }
    _db.execute('BEGIN');
    _recordTransaction = true;
    _recordPending = 0;
    try {
      await validate();
      _db.execute('COMMIT');
      _recordTransaction = false;
    } catch (original) {
      // A rollback failure leaves ownership live; release retries it and never
      // grants preview authority to this provisional database.
      try {
        if (_recordTransaction) {
          _db.execute('ROLLBACK');
          _recordTransaction = false;
        }
      } catch (cleanup) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }

  /// A fresh validator must rebuild all derived indexes; successful earlier
  /// validation batches may already have committed before a later failure.
  void resetDerivedRecords() {
    if (_writing || _closed || _recordTransaction) {
      throw StateError('Invalid revalidation phase');
    }
    final count =
        _db.select('SELECT count(*) AS n FROM records').single['n'] as int;
    budget.visit(count + 1);
    _db.execute('DELETE FROM records');
  }

  /// Preserve original literals inside the same encrypted owner. This method
  /// never edits identities, relation edges, recurrence ordinals or arbitrary
  /// JSON subtrees. A separate bounded recurrence plan owns those operations.
  void editTimeScalars(List<BackupTimeScalarEdit> edits) {
    if (_writing ||
        _closed ||
        _recordTransaction ||
        edits.isEmpty ||
        edits.length > 4) {
      throw StateError('Invalid time edit phase');
    }
    const allowed = {
      'civilTime',
      'timeZoneId',
      'occurrenceOffsetSeconds',
      'recurringOverrides',
      'startedAt',
      'finishedAt',
      'createdAt',
      'updatedAt',
    };
    final keys = <String>{};
    for (final edit in edits) {
      budget.visit();
      if (!allowed.contains(edit.field) ||
          !keys.add('${edit.parent}:${edit.field}') ||
          (edit.value is! String && edit.value is! int)) {
        BackupLimits.invalid();
      }
      if (edit.value is String) BackupLimits.string(edit.value as String);
      if (node(edit.parent)['kind'] != 'object') BackupLimits.invalid();
      final existing = child(edit.parent, edit.field);
      if ((existing != null) != edit.expectedExists ||
          (existing != null && scalar(existing) != edit.expectedValue)) {
        throw StateError('Candidate field changed');
      }
      final previousBytes = existing == null
          ? 0
          : utf8.encode(jsonEncode(edit.expectedValue)).length;
      final nextBytes =
          utf8.encode(jsonEncode(edit.value)).length +
          (existing == null
              ? utf8.encode(jsonEncode(edit.field)).length + 2
              : 0);
      if (nextBytes > previousBytes) {
        budget.plaintext(nextBytes - previousBytes);
      }
    }
    _db.execute('BEGIN');
    _recordTransaction = true;
    try {
      for (final edit in edits) {
        final existing = _db.select(
          'SELECT kind,value FROM nodes WHERE parent=? AND key=?',
          [edit.parent, edit.field],
        );
        _db.execute(
          'INSERT OR IGNORE INTO original_time_fields(parent,field,existed,kind,value) VALUES(?,?,?,?,?)',
          [
            edit.parent,
            edit.field,
            existing.isEmpty ? 0 : 1,
            existing.isEmpty ? null : existing.single['kind'],
            existing.isEmpty ? null : existing.single['value'],
          ],
        );
        final kind = edit.value is String ? 'string' : 'number';
        final value = edit.value is String
            ? edit.value
            : jsonEncode(edit.value);
        if (existing.isEmpty) {
          _db.execute(
            'INSERT INTO nodes(parent,key,kind,value) VALUES(?,?,?,?)',
            [edit.parent, edit.field, kind, value],
          );
        } else {
          _db.execute(
            'UPDATE nodes SET kind=?,value=? WHERE parent=? AND key=?',
            [kind, value, edit.parent, edit.field],
          );
        }
      }
      _db.execute('COMMIT');
      _recordTransaction = false;
    } catch (original) {
      try {
        _db.execute('ROLLBACK');
        _recordTransaction = false;
      } catch (cleanup) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }

  /// Atomically closes one source segment, moves a finite set of schedules,
  /// and appends its new segment/exclusions. Original scalars stay encrypted.
  /// Derived records deliberately remain stale until the owner runs a fresh
  /// whole-candidate validation pass; this method grants no ready authority.
  void editRecurringTimePlan({
    required int segmentArray,
    required int exclusionArray,
    required List<BackupRecurringScalarEdit> edits,
    required Map<String, Object?> newSegment,
    required List<Map<String, Object?>> newExclusions,
  }) {
    if (_writing ||
        _closed ||
        _recordTransaction ||
        edits.isEmpty ||
        edits.length > BackupLimits.schedules * 7 + 1 ||
        newExclusions.length > BackupLimits.records) {
      BackupLimits.invalid();
    }
    if (node(segmentArray)['kind'] != 'array' ||
        node(exclusionArray)['kind'] != 'array') {
      BackupLimits.invalid();
    }
    const scheduleFields = {
      'civilTime',
      'timeZoneId',
      'occurrenceOffsetSeconds',
      'recurringSegmentId',
      'recurringSlotKey',
      'recurringOrdinal',
      'recurringOverrides',
    };
    final seen = <String>{};
    var closed = 0;
    for (final edit in edits) {
      budget.visit();
      if (!seen.add('${edit.parent}:${edit.field}') ||
          record(edit.kind, edit.identity)?['node'] != edit.parent ||
          !(edit.kind == 'segment' && edit.field == 'beforeSlot' ||
              edit.kind == 'schedule' && scheduleFields.contains(edit.field))) {
        BackupLimits.invalid();
      }
      if (edit.kind == 'segment') closed++;
      final existing = child(edit.parent, edit.field);
      if ((existing != null) != edit.expectedExists ||
          (existing != null && scalar(existing) != edit.expectedValue)) {
        throw StateError('Candidate field changed');
      }
      final next = edit.value;
      if (next != null && next is! String && next is! int) {
        BackupLimits.invalid();
      }
      if (next is String) BackupLimits.string(next);
      final growth =
          utf8.encode(jsonEncode(next)).length -
          (existing == null
              ? 0
              : utf8.encode(jsonEncode(edit.expectedValue)).length) +
          (existing == null
              ? utf8.encode(jsonEncode(edit.field)).length + 2
              : 0);
      if (growth > 0) budget.plaintext(growth);
    }
    if (closed != 1 || record('segment', newSegment['id'] as String) != null) {
      BackupLimits.invalid();
    }
    const segmentFields = {
      'id',
      'seriesId',
      'preparationId',
      'fromSlot',
      'beforeSlot',
      'createdAt',
      'preparationNotBefore',
      'ruleJson',
      'scheduleJson',
    };
    if (newSegment.keys.toSet().difference(segmentFields).isNotEmpty ||
        !newSegment.keys.toSet().containsAll(segmentFields)) {
      BackupLimits.invalid();
    }
    for (final object in [newSegment, ...newExclusions]) {
      budget.admit();
      budget.visit(object.length + 1);
      if (!identical(object, newSegment) &&
          (object.length != 3 ||
              !object.keys.toSet().containsAll({
                'segmentId',
                'slotKey',
                'ordinal',
              }) ||
              object['segmentId'] != newSegment['id'])) {
        BackupLimits.invalid();
      }
      for (final value in object.values) {
        if (value != null && value is! String && value is! int) {
          BackupLimits.invalid();
        }
        if (value is String) BackupLimits.string(value);
      }
      budget.plaintext(utf8.encode(jsonEncode(object)).length + 1);
    }
    String kind(Object? value) => value == null
        ? 'null'
        : value is String
        ? 'string'
        : 'number';
    Object? encoded(Object? value) => value == null
        ? null
        : value is String
        ? value
        : jsonEncode(value);
    void append(int parent, Map<String, Object?> object) {
      final key =
          (_db.select('SELECT count(*) AS n FROM nodes WHERE parent=?', [
                    parent,
                  ]).single['n']
                  as int)
              .toString();
      _db.execute('INSERT INTO nodes(parent,key,kind) VALUES(?,?,?)', [
        parent,
        key,
        'object',
      ]);
      final id = _db.lastInsertRowId;
      for (final entry in object.entries) {
        _db.execute(
          'INSERT INTO nodes(parent,key,kind,value) VALUES(?,?,?,?)',
          [id, entry.key, kind(entry.value), encoded(entry.value)],
        );
      }
    }

    _db.execute('BEGIN');
    _recordTransaction = true;
    try {
      for (final edit in edits) {
        final existing = _db.select(
          'SELECT kind,value FROM nodes WHERE parent=? AND key=?',
          [edit.parent, edit.field],
        );
        _db.execute(
          'INSERT OR IGNORE INTO original_time_fields(parent,field,existed,kind,value) VALUES(?,?,?,?,?)',
          [
            edit.parent,
            edit.field,
            existing.isEmpty ? 0 : 1,
            existing.isEmpty ? null : existing.single['kind'],
            existing.isEmpty ? null : existing.single['value'],
          ],
        );
        if (existing.isEmpty) {
          _db.execute(
            'INSERT INTO nodes(parent,key,kind,value) VALUES(?,?,?,?)',
            [edit.parent, edit.field, kind(edit.value), encoded(edit.value)],
          );
        } else {
          _db.execute(
            'UPDATE nodes SET kind=?,value=? WHERE parent=? AND key=?',
            [kind(edit.value), encoded(edit.value), edit.parent, edit.field],
          );
        }
      }
      append(segmentArray, newSegment);
      for (final exclusion in newExclusions) {
        append(exclusionArray, exclusion);
      }
      _db.execute('COMMIT');
      _recordTransaction = false;
    } catch (original) {
      try {
        _db.execute('ROLLBACK');
        _recordTransaction = false;
      } catch (cleanup) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }

  Object? originalTimeScalar(int parent, String field) {
    budget.visit();
    final original = _db.select(
      'SELECT existed,kind,value FROM original_time_fields WHERE parent=? AND field=?',
      [parent, field],
    );
    if (original.isEmpty) {
      final id = child(parent, field);
      return id == null ? null : scalar(id);
    }
    final row = original.single;
    return row['existed'] == 0 || row['value'] == null
        ? null
        : row['kind'] == 'string'
        ? row['value']
        : jsonDecode(row['value'] as String);
  }

  String fieldPath(int parent, String field) {
    final parts = <String>[field];
    int? current = parent;
    while (current != null) {
      final value = node(current);
      final owner = value['parent'] as int?;
      if (owner == null) break;
      final key = value['key'] as String;
      parts.add(node(owner)['kind'] == 'array' ? '[$key]' : key);
      current = owner;
      if (parts.length > BackupLimits.depth + 1) BackupLimits.invalid();
    }
    return parts.reversed.join('.').replaceAll('.[', '[');
  }

  List<Map<String, Object?>> timeIssuePage(int after) => _db.select(
    "SELECT * FROM records WHERE kind='timeIssue' AND node>? ORDER BY node LIMIT 21",
    [after],
  );

  /// Explicit UI pagination is separately bounded per user request. It does
  /// not re-run validation or spend a file's validation-work allowance.
  List<Map<String, Object?>> impactPage(int after) => _db.select(
    "SELECT r.node,r.detail,(SELECT value FROM nodes WHERE parent=r.node AND key='name') AS name,(SELECT value FROM nodes WHERE parent=r.node AND key='civilTime') AS civil,(SELECT value FROM nodes WHERE parent=r.node AND key='timeZoneId') AS zone,(SELECT value FROM nodes WHERE parent=r.node AND key='occurrenceOffsetSeconds') AS offset FROM records r WHERE r.kind='timezoneChange' AND r.node>? ORDER BY r.node LIMIT 21",
    [after],
  );

  int recordCount(String kind) {
    final count =
        _db.select('SELECT count(*) AS n FROM records WHERE kind=?', [
              kind,
            ]).single['n']
            as int;
    budget.visit(count);
    return count;
  }

  Map<String, Object?>? record(String kind, String identity) {
    budget.visit();
    final rows = _db.select(
      'SELECT * FROM records WHERE kind=? AND identity=?',
      [kind, identity],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Iterable<Map<String, Object?>> occurrences(String segment) sync* {
    var after = '';
    while (true) {
      final batch = _db.select(
        "SELECT * FROM records WHERE kind='occurrence' AND reference=? AND slot>? ORDER BY slot LIMIT 64",
        [segment, after],
      );
      if (batch.isEmpty) return;
      for (final row in batch) {
        budget.visit();
        after = row['slot'] as String;
        yield row;
      }
    }
  }

  Map<String, Object?>? lastOccurrence(String segment) {
    budget.visit();
    final rows = _db.select(
      "SELECT * FROM records WHERE kind='occurrence' AND reference=? ORDER BY slot DESC LIMIT 1",
      [segment],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Map<String, Object?>? recordAtSlot(
    String kind,
    String reference,
    String slot,
  ) {
    budget.visit();
    final rows = _db.select(
      'SELECT * FROM records WHERE kind=? AND reference=? AND slot=?',
      [kind, reference, slot],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Iterable<Map<String, Object?>> records(String kind, {String? owner}) sync* {
    var after = 0;
    while (true) {
      final batch = _db.select(
        owner == null
            ? 'SELECT * FROM records WHERE kind=? AND node>? ORDER BY node LIMIT 64'
            : 'SELECT * FROM records WHERE kind=? AND owner=? AND node>? ORDER BY node LIMIT 64',
        owner == null ? [kind, after] : [kind, owner, after],
      );
      if (batch.isEmpty) return;
      for (final row in batch) {
        budget.visit();
        after = row['node'] as int;
        yield row;
      }
    }
  }

  Future<void> release() async {
    if (_released) return;
    if (!_closed) {
      Object? first;
      try {
        if (_writing || _recordTransaction) {
          _db.execute('ROLLBACK');
          _writing = false;
          _recordTransaction = false;
        }
      } catch (error) {
        first = error;
      }
      try {
        if (!_statementClosed) {
          _insert.dispose();
          _statementClosed = true;
        }
      } catch (error) {
        first ??= error;
      }
      try {
        _db.dispose();
        _closed = true;
      } catch (error) {
        throw BackupProcessingCleanupFailure(
          originalError: first,
          cleanupError: error,
        );
      }
      // A confirmed DB close also finalizes its statements. File deletion can be
      // retried independently, but a failed DB close never authorizes deletion.
      if (first != null) {
        try {
          await _remove();
          _released = true;
        } catch (cleanup) {
          throw BackupProcessingCleanupFailure(
            originalError: first,
            cleanupError: cleanup,
          );
        }
        throw first;
      }
    }
    await _remove();
    _released = true;
  }
}
