import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'backup_limits.dart';
import 'restore_staging.dart';

/// A point-in-time, encrypted, immutable source for both export encoding passes.
/// The caller owns the source writer gate only until [create] returns. Neither
/// pass reads the active database. No complete portable payload is collected.
final class BackupExportSnapshot {
  BackupExportSnapshot._(
    this._staging,
    this.cutoff,
    this.sourceAppVersion,
    this.sourcePlatform,
    this.budget,
    this._profile,
  );

  final RestoreStaging _staging;
  final DateTime cutoff;
  final String sourceAppVersion;
  final String sourcePlatform;
  final BackupBudget budget;
  final Map<String, Object?> _profile;
  bool _released = false;
  bool _encoding = false;
  AppDatabase get _database => _staging.database;
  int get dataRevision => _integer(_profile['data_revision']);

  static Future<BackupExportSnapshot> create(
    AppDatabase source, {
    required DateTime cutoff,
    required String sourceAppVersion,
    required String sourcePlatform,
    required BackupBudget budget,
    RestoreStagingFactory? stagingFactory,
  }) async {
    budget.lease?.check();
    BackupLimits.string(sourceAppVersion);
    BackupLimits.string(sourcePlatform);
    if (cutoff.year < 1 || cutoff.year > 9999) BackupLimits.invalid();
    final staging = await (stagingFactory ?? RestoreStaging.create)();
    try {
      await source.transaction(() async {
        await copyPortableBackupRows(source, staging.database, budget: budget);
      });
      // No public mutable database handle escapes. The engine also refuses
      // accidental writes during the two separate serializer traversals.
      await staging.database.customStatement('PRAGMA query_only = ON');
      Map<String, Object?>? profile;
      await for (final row in _rows(staging.database, _tables.first, budget)) {
        if (profile != null || row['id'] != localProfileId) {
          BackupLimits.invalid();
        }
        profile = row;
      }
      if (profile == null) BackupLimits.invalid();
      BackupLimits.integer(
        profile['data_revision'],
        maximum: BackupLimits.exactInteger - 1,
      );
      return BackupExportSnapshot._(
        staging,
        cutoff.toUtc(),
        sourceAppVersion,
        sourcePlatform,
        budget,
        profile,
      );
    } catch (original) {
      try {
        await staging.release();
      } catch (cleanup) {
        budget.lease?.retainCleanup(staging.release);
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }

  /// Deterministic JSON/UTF-8 fragments. The integration layer counts/hashes and
  /// validates pass one, then verifies identical length/digest during encryption.
  /// It alone charges whole plaintext size, avoiding double charging two passes.
  Stream<List<int>> plaintext() async* {
    if (_released || _encoding) throw StateError('Snapshot is unavailable');
    _encoding = true;
    // Coalesce tiny JSON punctuation/fields into a fixed-size output buffer.
    // A full payload is never collected, and yielded buffers are never reused.
    var output = Uint8List(16384);
    var filled = 0;
    budget.buffer(output.length);
    try {
      await for (final fragment in _json()) {
        budget.lease?.check();
        // Split JSON text without separating a UTF-16 surrogate pair. A piece
        // is at most 4096 UTF-16 units, hence at most 16384 UTF-8 bytes.
        for (var start = 0; start < fragment.length;) {
          var end = (start + 4096).clamp(0, fragment.length);
          if (end < fragment.length) {
            final last = fragment.codeUnitAt(end - 1);
            if (last >= 0xd800 && last <= 0xdbff) end--;
          }
          final bytes = utf8.encode(fragment.substring(start, end));
          budget.buffer(bytes.length);
          for (var at = 0; at < bytes.length;) {
            final count = (bytes.length - at).clamp(0, output.length - filled);
            output.setRange(filled, filled + count, bytes, at);
            filled += count;
            at += count;
            if (filled == output.length) {
              yield output;
              budget.lease?.check();
              output = Uint8List(16384);
              filled = 0;
            }
          }
          start = end;
        }
      }
      if (filled != 0) yield Uint8List.sublistView(output, 0, filled);
    } finally {
      _encoding = false;
    }
  }

  Stream<String> _json() async* {
    yield '{"formatVersion":2,"cutoff":';
    yield* _value(cutoff.toIso8601String());
    yield ',"sourceAppVersion":';
    yield* _value(sourceAppVersion);
    yield ',"sourcePlatform":';
    yield* _value(sourcePlatform);
    yield ',"dataRevision":';
    yield* _value(dataRevision);
    yield ',"profile":';
    yield* _value({
      'spareTimeMinutes': _profile['spare_time'],
      'note': _profile['note'],
      'isOnboardingCompleted': _boolean(_profile['is_onboarding_completed']),
      'eligibleOutcomeCount': _profile['eligible_outcome_count'],
      'onTimeOutcomeCount': _profile['on_time_outcome_count'],
    });
    yield ',"preferences":';
    yield* _value({
      'alarmsEnabled': _boolean(_profile['alarms_enabled']),
      'alarmOffsetMinutes': _profile['alarm_offset_minutes'],
      'detailedNotificationContent': _boolean(
        _profile['detailed_notification_content'],
      ),
    });
    yield ',"defaultPreparation":';
    yield* _linkedPreparation('preparation_users', 'user_id', localProfileId);
    yield ',"schedules":[';
    var first = true;
    await for (final row in _schedulesWithPlaces()) {
      if (!first) yield ',';
      first = false;
      if (row['_place_name'] is! String) BackupLimits.invalid();
      yield* _value(
        _schedule(row, {
          'id': row['place_id'],
          'place_name': row['_place_name'],
        }),
      );
    }
    yield '],"schedulePreparations":{';
    first = true;
    await for (final row in _tableRows('schedules')) {
      if (!first) yield ',';
      first = false;
      yield* _value(row['id']);
      yield ':';
      yield* _linkedPreparation(
        'preparation_schedules',
        'schedule_id',
        row['id'],
      );
    }
    yield '},"templates":[';
    first = true;
    await for (final row in _tableRows('preparation_templates')) {
      if (!first) yield ',';
      first = false;
      yield '{"id":';
      yield* _value(row['id']);
      yield ',"name":';
      yield* _value(row['template_name']);
      yield ',"createdAt":';
      yield* _value(_instant(row['created_at']));
      yield ',"updatedAt":';
      yield* _value(_instant(row['updated_at']));
      yield ',"preparation":';
      yield* _templatePreparation(row['id']);
      yield '}';
    }
    yield '],"recurring":{';
    first = true;
    for (final entry in const {
      'definitions': 'preparation_definitions',
      'steps': 'preparation_definition_steps',
      'segments': 'recurring_schedule_segments',
      'exclusions': 'recurring_schedule_exclusions',
    }.entries) {
      if (!first) yield ',';
      first = false;
      yield '${jsonEncode(entry.key)}:[';
      var firstRow = true;
      await for (final row in _tableRows(entry.value)) {
        if (!firstRow) yield ',';
        firstRow = false;
        yield* _value(_recurring(entry.key, row));
      }
      yield ']';
    }
    yield '}}';
  }

  Stream<Map<String, Object?>> _tableRows(
    String table, {
    String? where,
    List<Object?> arguments = const [],
  }) => _rows(
    _database,
    _tables.firstWhere((t) => t.name == table),
    budget,
    where: where,
    arguments: arguments,
  );

  // The snapshot was scalar-checked before copy and is now query-only. Join
  // this bounded page directly rather than issuing a place query per schedule.
  Stream<Map<String, Object?>> _schedulesWithPlaces() async* {
    final columns = _tables
        .firstWhere((t) => t.name == 'schedules')
        .columns
        .keys;
    int? cursor;
    while (true) {
      budget.lease?.check();
      final rows = await _database
          .customSelect(
            'SELECT s.rowid AS _cursor,${columns.map((c) => 's."$c"').join(',')},'
            'p.place_name AS _place_name FROM schedules s LEFT JOIN places p ON p.id=s.place_id '
            '${cursor == null ? '' : 'WHERE s.rowid > ? '}ORDER BY s.rowid LIMIT 16',
            variables: [if (cursor != null) Variable<int>(cursor)],
          )
          .get();
      if (rows.isEmpty) return;
      for (final row in rows) {
        budget.visit();
        cursor = row.read<int>('_cursor');
        yield row.data;
      }
    }
  }

  Stream<String> _linkedPreparation(
    String table,
    String ownerColumn,
    Object? owner,
  ) async* {
    yield '[';
    var count = 0;
    await for (final row in _tableRows(
      table,
      where: '$ownerColumn = ?',
      arguments: [owner],
    )) {
      if (++count > BackupLimits.preparationSteps) {
        BackupLimits.exceeded('preparationSteps');
      }
      if (count > 1) yield ',';
      // Preserve raw edges. The shared validator must reject, not silently fix,
      // a cycle, multiple heads, disconnected graph or cross-owner reference.
      yield* _value({
        'id': row['id'],
        'name': row['preparation_name'],
        'minutes': row['preparation_time'],
        'nextId': row['next_preparation_id'],
      });
    }
    yield ']';
  }

  Stream<String> _templatePreparation(Object? owner) async* {
    // A definition is bounded at 1000 steps. Query 1001 before materializing to
    // detect overflow, with every source scalar bounded by the snapshot copy.
    final rows = await _database
        .customSelect(
          'SELECT id,preparation_name,preparation_time,position FROM preparation_template_steps '
          'WHERE template_id=? ORDER BY position,id LIMIT ${BackupLimits.preparationSteps + 1}',
          variables: [Variable<String>(owner as String)],
        )
        .get();
    budget.visit(rows.length);
    if (rows.length > BackupLimits.preparationSteps) {
      BackupLimits.exceeded('preparationSteps');
    }
    yield '[';
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i].data;
      if (row['position'] != i) BackupLimits.invalid();
      if (i > 0) yield ',';
      yield* _value({
        'id': row['id'],
        'name': row['preparation_name'],
        'minutes': row['preparation_time'],
        'nextId': i + 1 < rows.length ? rows[i + 1].data['id'] : null,
      });
    }
    yield ']';
  }

  Stream<String> _value(Object? value) async* {
    budget.visit();
    if (value is Map<String, Object?>) {
      yield '{';
      var first = true;
      for (final entry in value.entries) {
        if (!first) yield ',';
        first = false;
        // These keys are fixed schema literals constructed above, not input
        // nodes. Charge the actual value traversal, not a second fake data node
        // for every constant field name. Dynamic schedule-owner keys still use
        // _value in _json and are charged normally.
        yield jsonEncode(entry.key);
        yield ':';
        yield* _value(entry.value);
      }
      yield '}';
    } else {
      if (value is String) BackupLimits.string(value);
      if (value != null &&
          value is! String &&
          value is! int &&
          value is! bool) {
        BackupLimits.invalid();
      }
      yield jsonEncode(value);
    }
  }

  Map<String, Object?> _schedule(
    Map<String, Object?> r,
    Map<String, Object?> place,
  ) => {
    'id': r['id'],
    'place': {'id': place['id'], 'name': place['place_name']},
    'name': r['schedule_name'],
    'civilTime': r['schedule_time'],
    'timeZoneId': r['time_zone_id'],
    'occurrenceOffsetSeconds': r['occurrence_offset_seconds'],
    'moveTimeMinutes': _durationMinutes(r['move_time']),
    'isChanged': _boolean(r['is_changed']),
    'spareTimeMinutes': _durationMinutes(r['schedule_spare_time']),
    'note': r['schedule_note'] ?? '',
    'latenessTime': r['lateness_time'],
    'doneStatus': r['done_status'],
    'finishedAt': _instant(r['finished_at']),
    'startedAt': _instant(r['started_at']),
    'preparationFrozen': _boolean(r['preparation_frozen']),
    'preparationMode': r['preparation_mode'],
    'preparationTemplateId': r['preparation_template_id'],
    'preparationTemplateName': r['preparation_template_name'],
    'preparationTemplateDeleted': _boolean(r['preparation_template_deleted']),
    'scoreContributionRecorded': _boolean(r['score_contribution_recorded']),
    'recurringSegmentId': r['recurring_segment_id'],
    'recurringSlotKey': r['recurring_slot_key'],
    'recurringOrdinal': r['recurring_ordinal'],
    'recurringOverrides': r['recurring_overrides'],
    'preparationDefinitionId': r['preparation_definition_id'],
  };

  Map<String, Object?> _recurring(String kind, Map<String, Object?> r) =>
      switch (kind) {
        'definitions' => {
          'id': r['id'],
          'ownerId': r['owner_id'],
          'scope': r['scope'],
          'name': r['name'],
          'createdAt': _millis(r['created_at']),
        },
        'steps' => {
          'id': r['id'],
          'definitionId': r['definition_id'],
          'name': r['name'],
          'minutes': r['minutes'],
          'position': r['position'],
        },
        'segments' => {
          'id': r['id'],
          'seriesId': r['series_id'],
          'ruleJson': r['rule_json'],
          'scheduleJson': r['schedule_json'],
          'preparationId': r['preparation_id'],
          'fromSlot': r['from_slot'],
          'beforeSlot': r['before_slot'],
          'createdAt': _millis(r['created_at']),
          'preparationNotBefore': _millis(r['preparation_not_before']),
        },
        'exclusions' => {
          'segmentId': r['segment_id'],
          'slotKey': r['slot_key'],
          'ordinal': r['ordinal'],
        },
        _ => throw StateError('Unknown portable table'),
      };

  Future<void> release() async {
    if (_released) return;
    if (_encoding) {
      throw StateError('Encoder must terminate before releasing snapshot');
    }
    await _staging.release();
    _released = true;
  }
}

int _integer(Object? value) {
  if (value is! int) BackupLimits.invalid();
  return value;
}

bool _boolean(Object? value) {
  if (value != 0 && value != 1) BackupLimits.invalid();
  return value == 1;
}

int? _durationMinutes(Object? value) {
  if (value == null) return null;
  // Only these two schedule columns store milliseconds. Format 1/2 historically
  // exports Duration.inMinutes (truncating a positive sub-minute remainder).
  // Check the original value before truncation so a negative millisecond cannot
  // become an apparently valid zero, and avoid Duration's microsecond overflow.
  final milliseconds = BackupLimits.integer(
    value,
    maximum: 0x7fffffffffffffff ~/ 1000,
  );
  return milliseconds ~/ 60000;
}

int? _millis(Object? value) {
  if (value == null) return null;
  final seconds = _integer(value);
  if (seconds < -62135596800 || seconds > 253402300799) BackupLimits.invalid();
  return seconds * 1000;
}

String? _instant(Object? value) {
  final millis = _millis(value);
  return millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          millis,
          isUtc: true,
        ).toIso8601String();
}

/// Copies only the existing portable fields into an already empty target.
/// The caller owns source consistency, target clearing and all
/// revision, recovery, delivery or activation authority. This helper does not
/// acquire gates, delete data, increment revisions or copy installation metadata.
Future<void> copyPortableBackupRows(
  AppDatabase source,
  AppDatabase target, {
  required BackupBudget budget,
}) {
  // Drift keeps one current connection in a zone. Entering the target's
  // transaction hides the source transaction, so source reads must explicitly
  // run in the caller's zone. Otherwise they queue behind the source transaction
  // that is itself waiting for this copy to finish.
  final sourceZone = Zone.current;
  return target.transaction(() async {
    // Linked preparation rows may precede their successor; enforce their foreign
    // keys at the end of the caller's transaction, never disable enforcement.
    await target.customStatement('PRAGMA defer_foreign_keys = ON');
    var copied = 0;
    var schedules = 0;
    for (final table in _tables) {
      final existing = await target
          .customSelect('SELECT 1 FROM "${table.name}" LIMIT 1')
          .get();
      if (existing.isNotEmpty) {
        throw StateError('Portable copy target must be empty');
      }
    }
    for (final table in _tables) {
      final columns = table.columns.keys.toList(growable: false);
      final sql =
          'INSERT INTO "${table.name}" (${columns.map((c) => '"$c"').join(',')}) '
          'VALUES (${List.filled(columns.length, '?').join(',')})';
      await for (final row in _rows(
        source,
        table,
        budget,
        queryZone: sourceZone,
      )) {
        if (++copied > BackupLimits.records) BackupLimits.exceeded('records');
        if (table.name == 'schedules' && ++schedules > BackupLimits.schedules) {
          BackupLimits.exceeded('schedules');
        }
        await target.customStatement(sql, [
          for (final column in columns) row[column],
        ]);
      }
    }
    final foreign = await target
        .customSelect('SELECT * FROM pragma_foreign_key_check LIMIT 1')
        .get();
    if (foreign.isNotEmpty) BackupLimits.invalid();
  });
}

final class _PortableTable {
  const _PortableTable(this.name, this.columns);
  final String name;
  // null means an SQLite integer; text limits apply before a cell crosses FFI.
  final Map<String, int?> columns;
}

const _id = BackupLimits.identifierBytes;
const _text = BackupLimits.stringBytes;
// Existing domain name limits are 30 UTF-16 units. This byte preflight is only
// an allocation guard; the shared validator enforces the exact name semantics.
const _shortName = 30 * 4;
const _tables = [
  _PortableTable('users', {
    'id': _id,
    'spare_time': null,
    'note': _text,
    'is_onboarding_completed': null,
    'eligible_outcome_count': null,
    'on_time_outcome_count': null,
    'alarms_enabled': null,
    'alarm_offset_minutes': null,
    'detailed_notification_content': null,
    'data_revision': null,
  }),
  _PortableTable('places', {'id': _id, 'place_name': _shortName}),
  _PortableTable('preparation_users', {
    'id': _id,
    'user_id': _id,
    'preparation_name': _shortName,
    'preparation_time': null,
    'next_preparation_id': _id,
  }),
  _PortableTable('preparation_templates', {
    'id': _id,
    'template_name': _shortName,
    'created_at': null,
    'updated_at': null,
  }),
  _PortableTable('preparation_template_steps', {
    'id': _id,
    'template_id': _id,
    'preparation_name': _shortName,
    'preparation_time': null,
    'position': null,
  }),
  _PortableTable('preparation_definitions', {
    'id': _id,
    'owner_id': _id,
    'scope': _text,
    'name': _text,
    'created_at': null,
  }),
  _PortableTable('preparation_definition_steps', {
    'id': _id,
    'definition_id': _id,
    'name': _shortName,
    'minutes': null,
    'position': null,
  }),
  _PortableTable('recurring_schedule_segments', {
    'id': _id,
    'series_id': _id,
    'rule_json': _text,
    'schedule_json': _text,
    'preparation_id': _id,
    'from_slot': _text,
    'before_slot': _text,
    'created_at': null,
    'preparation_not_before': null,
  }),
  _PortableTable('recurring_schedule_exclusions', {
    'segment_id': _id,
    'slot_key': _text,
    'ordinal': null,
  }),
  _PortableTable('schedules', {
    'id': _id,
    'place_id': _id,
    'schedule_name': _text,
    'time_zone_id': _id,
    'occurrence_offset_seconds': null,
    'schedule_time': _text,
    'move_time': null,
    'is_changed': null,
    'schedule_spare_time': null,
    'schedule_note': _text,
    'lateness_time': null,
    'done_status': _text,
    'started_at': null,
    'finished_at': null,
    'preparation_mode': _text,
    'preparation_template_id': _id,
    'preparation_template_name': _text,
    'preparation_template_deleted': null,
    'preparation_frozen': null,
    'score_contribution_recorded': null,
    'recurring_segment_id': _id,
    'recurring_slot_key': _text,
    'recurring_ordinal': null,
    'recurring_overrides': _text,
    'preparation_definition_id': _id,
  }),
  _PortableTable('preparation_schedules', {
    'id': _id,
    'schedule_id': _id,
    'preparation_name': _shortName,
    'preparation_time': null,
    'next_preparation_id': _id,
  }),
];

/// Keyset pagination includes negative/zero rowids on the first page. CASE
/// suppresses malformed/oversized cells before they can be copied into Dart.
/// The UTF-8 byte length is evaluated only after a bounded character length.
Stream<Map<String, Object?>> _rows(
  AppDatabase db,
  _PortableTable table,
  BackupBudget budget, {
  String? where,
  List<Object?> arguments = const [],
  Zone? queryZone,
}) async* {
  final projections = <String>['rowid AS "_cursor"'];
  var index = 0;
  for (final entry in table.columns.entries) {
    final column = '"${entry.key}"';
    final max = entry.value;
    final guard = max == null
        ? "CASE WHEN $column IS NULL OR typeof($column)='integer' THEN 0 ELSE 2 END"
        : "CASE WHEN $column IS NULL THEN 0 WHEN typeof($column)<>'text' THEN 2 "
              "WHEN length($column)>$max THEN 1 WHEN length(CAST($column AS BLOB))>$max THEN 1 ELSE 0 END";
    projections.add(
      'CASE WHEN ($guard)=0 THEN $column ELSE NULL END AS $column',
    );
    projections.add('($guard) AS "_guard${index++}"');
  }
  int? cursor;
  while (true) {
    budget.lease?.check();
    final predicates = [
      if (where != null) '($where)',
      if (cursor != null) 'rowid > ?',
    ];
    final rows = await (queryZone ?? Zone.current).run(
      () => db
          .customSelect(
            'SELECT ${projections.join(',')} FROM "${table.name}" '
            '${predicates.isEmpty ? '' : 'WHERE ${predicates.join(' AND ')} '}ORDER BY rowid LIMIT 16',
            variables: [
              for (final v in [...arguments, ?cursor])
                if (v is int)
                  Variable<int>(v)
                else if (v is String)
                  Variable<String>(v)
                else
                  throw ArgumentError(
                    'Portable query requires an integer or string argument',
                  ),
            ],
          )
          .get(),
    );
    if (rows.isEmpty) return;
    for (final row in rows) {
      budget.visit();
      for (var i = 0; i < table.columns.length; i++) {
        final flag = row.read<int>('_guard$i');
        if (flag == 1) BackupLimits.exceeded('sourceScalar');
        if (flag != 0) BackupLimits.invalid();
      }
      cursor = row.read<int>('_cursor');
      yield {for (final name in table.columns.keys) name: row.data[name]};
    }
  }
}
