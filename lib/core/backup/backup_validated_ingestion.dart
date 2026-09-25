import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/entities/backup_recurring_time_review.dart';
import 'package:on_time_front/data/mappers/recurrence_codec.dart';
import '../time/recurring_time_correction_mapping.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import '../time/schedule_time_resolution.dart';
import '../time/time_correction_conflicts.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import '../time/civil_time_resolver.dart';
import '../time/time_zone_rules.dart';
import 'package:collection/collection.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurrence_reference_policy.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:drift/drift.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'backup_recurrence_scan.dart';
import 'backup_content.dart';
import 'backup_crypto.dart';
import 'backup_ingestion_store.dart';
import 'backup_json_reader.dart';
import 'backup_limits.dart';
import 'backup_value_validation.dart';

part 'backup_authenticated_time_review.dart';
part 'backup_time_conflict_world.dart';
part 'backup_recurring_time_review.dart';

/// Authenticated, disk-indexed portable records. This owner never captures a
/// whole BackupContent or opens the active/original database to validate input.
class BackupValidatedIngestion {
  BackupValidatedIngestion._(
    this.store,
    this.root,
    this.nowUtc, [
    this.offsetLookup = backupOffsets,
    this._collectTimeIssues = false,
  ]);
  final BackupIngestionStore store;
  final int root;
  final DateTime nowUtc;
  final BackupOffsetLookup offsetLookup;
  final bool _collectTimeIssues;
  int timeIssueCount = 0;
  late final BackupContent
  metadata; // Bounded header only, all collections empty.
  late final int _default;
  int _scheduleCount = 0;
  int _templateCount = 0;
  int _defaultCount = 0;
  int timezoneChangeCount = 0;
  int uncertainHistoryCount = 0;
  final _uncertainExamples = <BackupHistoryUncertainty>[];
  bool _validated = false;
  final _specCache = <String, _SegmentSpec>{};
  BackupBudget get budget => store.budget;

  static Future<BackupValidatedIngestion> decrypt({
    required Stream<List<int>> ciphertext,
    required String password,
    required BackupCrypto crypto,
    required BackupBudget budget,
    Future<BackupIngestionStore> Function(BackupBudget)? createStore,
    DateTime? nowUtc,
  }) async {
    final store = await (createStore ?? BackupIngestionStore.create)(budget);
    try {
      final root = await BackupJsonReader(store, budget, portableRecords: true)
          .read(
            crypto.decryptStream(
              container: ciphertext,
              password: password,
              budget: budget,
            ),
          );
      // decryptStream has checked final authentication, frameCount and actual EOF.
      store.finish();
      final result = BackupValidatedIngestion._(
        store,
        root,
        (nowUtc ?? DateTime.now()).toUtc(),
      );
      await store.validateRecords(result._validate);
      result._validated = true;
      return result;
    } catch (original) {
      try {
        await store.release();
      } catch (cleanup) {
        budget.lease?.retainCleanup(store.release);
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }

  /// Internal owned snapshot admission; no user-supplied plaintext file enters
  /// this boundary. The source is an immutable encrypted export snapshot.
  static Future<BackupValidatedIngestion> validateOwnedSnapshot({
    required Stream<List<int>> plaintext,
    required BackupBudget budget,
    required Future<BackupIngestionStore> Function(BackupBudget) createStore,
    required DateTime nowUtc,
  }) async {
    final store = await createStore(budget);
    try {
      final root = await BackupJsonReader(
        store,
        budget,
        portableRecords: true,
      ).read(plaintext);
      store.finish();
      final result = BackupValidatedIngestion._(store, root, nowUtc.toUtc());
      await store.validateRecords(result._validate);
      result._validated = true;
      return result;
    } catch (original) {
      try {
        await store.release();
      } catch (cleanup) {
        budget.lease?.retainCleanup(store.release);
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }

  /// Explicit plaintext test adapter. Production enters only through decrypt().
  static Future<BackupValidatedIngestion> validateTestStore(
    BackupIngestionStore store,
    int root, {
    required DateTime nowUtc,
    BackupOffsetLookup offsetLookup = backupOffsets,
  }) async {
    store.finish();
    final value = BackupValidatedIngestion._(
      store,
      root,
      nowUtc.toUtc(),
      offsetLookup,
    );
    await store.validateRecords(value._validate);
    value._validated = true;
    return value;
  }

  final _effectivePreparationCache = <String, PreparationEntity>{};

  PreparationEntity _definitionPreparation(String id) {
    final steps = [
      for (final row in store.records('definitionStep', owner: id))
        _definitionStep(row['node'] as int),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return PreparationEntity(
      preparationStepList: [
        for (var i = 0; i < steps.length; i++)
          PreparationStepEntity(
            id: steps[i].id,
            preparationName: steps[i].name,
            preparationTime: Duration(minutes: steps[i].minutes),
            nextPreparationId: i + 1 < steps.length ? steps[i + 1].id : null,
          ),
      ],
    );
  }

  PreparationEntity _effectivePreparation(ScheduleEntity schedule) {
    final existing = _effectivePreparationCache[schedule.id];
    if (existing != null) return existing;
    PreparationEntity? preparation;
    if (!schedule.preparationFrozen &&
        schedule.preparationMode == SchedulePreparationMode.template &&
        schedule.preparationTemplateId != null &&
        !schedule.preparationTemplateDeleted) {
      final template = store.record(
        'template',
        schedule.preparationTemplateId!,
      );
      if (template != null) {
        preparation = _template(template['node'] as int).preparation;
      }
    }
    if (preparation == null) {
      final own = store.record('schedulePreparation', schedule.id);
      preparation = schedule.preparationDefinitionId != null
          ? _definitionPreparation(schedule.preparationDefinitionId!)
          : own == null
          ? const PreparationEntity(preparationStepList: [])
          : _preparation(own['node'] as int, 'scheduleStep', schedule.id);
      if (!schedule.preparationFrozen &&
          preparation.preparationStepList.isEmpty) {
        preparation = _preparation(_default, 'userStep', localProfileId);
      }
    }
    if (_effectivePreparationCache.length == 16) {
      _effectivePreparationCache.remove(_effectivePreparationCache.keys.first);
    }
    _effectivePreparationCache[schedule.id] = preparation;
    return preparation;
  }

  Duration _leadFor(ScheduleEntity schedule) =>
      _effectivePreparation(schedule).totalDuration +
      schedule.moveTime +
      (schedule.scheduleSpareTime ?? Duration.zero);

  String? _authorityRules;
  DateTime? _authorityBefore;

  /// A ready preview is valid only while its time classifications remain valid.
  /// This bound is separate from the active-store generation/revision authority.
  void establishTimeAuthority(String rulesIdentity) {
    if (!_validated) throw StateError('No provisional time authority');
    _authorityRules = rulesIdentity;
    void boundary(DateTime value) {
      if (!value.isBefore(nowUtc) &&
          (_authorityBefore == null || value.isBefore(_authorityBefore!))) {
        _authorityBefore = value;
      }
    }

    for (final row in store.records('schedule')) {
      final schedule = _schedule(row['node'] as int);
      if (RecurrenceReferencePolicy.hasProtectedFacts(schedule) ||
          !TimeZoneRules.contains(schedule.timeZoneId)) {
        continue;
      }
      final candidates = offsetLookup(
        schedule.scheduleTime,
        schedule.timeZoneId,
        budget,
      );
      final offset =
          schedule.occurrenceOffsetSeconds ??
          (candidates.length == 1 ? candidates.single : null);
      if (offset == null) continue;
      final instant = CivilDateTime.fromFields(
        schedule.scheduleTime,
      ).atOffset(offset);
      if (instant.isBefore(nowUtc)) continue;
      boundary(instant);
      boundary(instant.subtract(_leadFor(schedule)));
    }
  }

  bool hasCurrentTimeAuthority(DateTime now) {
    final rules = _authorityRules;
    if (rules == null) {
      return true; // Export/owned snapshot has no preview claim.
    }
    final utc = now.toUtc();
    return !utc.isBefore(nowUtc) &&
        (_authorityBefore == null || utc.isBefore(_authorityBefore!)) &&
        TimeZoneRules.loadedIdentity == rules;
  }

  BackupRestorePreview get preview {
    if (!_validated) {
      throw StateError('Provisional content cannot be previewed');
    }
    return BackupRestorePreview(
      cutoff: metadata.cutoff,
      cutoffLiteral: metadata.cutoffLiteral,
      sourceAppVersion: metadata.sourceAppVersion,
      sourcePlatform: metadata.sourcePlatform,
      scheduleCount: _scheduleCount,
      templateCount: _templateCount,
      defaultPreparationStepCount: _defaultCount,
      timezoneChangeCount: timezoneChangeCount,
      uncertainHistoryCount: uncertainHistoryCount,
      uncertainHistoryExamples: List.unmodifiable(_uncertainExamples),
    );
  }

  Future<BackupTimeZoneImpactPage> timeZoneImpacts({String? cursor}) async {
    if (!_validated) throw StateError('No provisional preview');
    final after = cursor == null ? 0 : int.tryParse(cursor);
    if (after == null || after < 0) {
      throw ArgumentError('Invalid preview cursor');
    }
    final rows = store.impactPage(after);
    final items = <BackupTimeZoneImpact>[];
    for (final row in rows.take(20)) {
      items.add(
        BackupTimeZoneImpact(
          name: row['name'] as String,
          civil: BackupValueValidation.date(
            row['civil'] as String,
            civilTime: true,
          ),
          zone: row['zone'] as String,
          previousOffset: row['offset'] == null
              ? null
              : int.parse(row['offset'] as String),
          newOffset: int.parse(row['detail'] as String),
        ),
      );
    }
    return BackupTimeZoneImpactPage(
      items,
      nextCursor: rows.length > 20 ? '${rows[19]['node']}' : null,
    );
  }

  Future<void> _validate() async {
    final header = store.fields(root, {
      'formatVersion',
      'cutoff',
      'sourceAppVersion',
      'sourcePlatform',
      'dataRevision',
    });
    final version = BackupLimits.integer(header['formatVersion']);
    if (version != 1 && version != 2) {
      throw const BackupProcessingFailure(
        BackupFailureKind.unsupportedRepresentation,
      );
    }
    header['profile'] = store
        .fields(store.requiredChild(root, 'profile', 'object'), {
          'spareTimeMinutes',
          'note',
          'isOnboardingCompleted',
          'eligibleOutcomeCount',
          'onTimeOutcomeCount',
        });
    header['preferences'] = store.fields(
      store.requiredChild(root, 'preferences', 'object'),
      {'alarmsEnabled', 'alarmOffsetMinutes', 'detailedNotificationContent'},
    );
    // Header validation shares the historical codec; no untrusted collections
    // are copied into this small object, nor is it a whole-backup adapter.
    metadata = BackupContent.fromJson({
      ...header,
      'formatVersion': 1,
      'schedules': <dynamic>[],
      'defaultPreparation': <dynamic>[],
      'schedulePreparations': <String, dynamic>{},
      'templates': <dynamic>[],
    });
    budget.admitValidated(); // profile
    budget.admitValidated(); // preferences
    _default = store.requiredChild(root, 'defaultPreparation', 'array');
    final defaultPreparation = _preparation(
      _default,
      'userStep',
      localProfileId,
      admit: true,
    );
    _defaultCount = defaultPreparation.preparationStepList.length;
    _durationSum(defaultPreparation);

    final schedules = store.requiredChild(root, 'schedules', 'array');
    for (final node in store.children(schedules)) {
      budget.admitValidated(schedule: true);
      final id = node['id'] as int;
      final schedule = _schedule(id);
      store.addRecord(
        'schedule',
        schedule.id,
        id,
        reference: schedule.recurringSegmentId,
        slot: schedule.recurringSlotKey,
        ordinal: schedule.recurringOrdinal,
        owner: schedule.preparationDefinitionId,
      );
      final priorPlace = store.record('place', schedule.place.id);
      if (priorPlace == null) {
        budget.admitValidated();
        store.addRecord(
          'place',
          schedule.place.id,
          id,
          detail: schedule.place.placeName,
        );
      } else if (priorPlace['detail'] != schedule.place.placeName) {
        BackupLimits.invalid();
      }
      final historical = _validateTime(schedule, id);
      if (schedule.recurringSegmentId != null &&
          schedule.recurringSlotKey != null &&
          schedule.recurringOrdinal != null) {
        store.addRecord(
          'occurrence',
          'schedule:${schedule.id}',
          id,
          reference: schedule.recurringSegmentId,
          slot: _civil(schedule.recurringSlotKey).toIso8601String(),
          ordinal: schedule.recurringOrdinal,
          owner: 'schedule',
          detail: historical ? 'past' : 'future',
        );
      }
      _scheduleCount++;
      if (_scheduleCount % 64 == 0) await Future<void>.delayed(Duration.zero);
    }

    final preparations = store.requiredChild(
      root,
      'schedulePreparations',
      'object',
    );
    for (final node in store.children(preparations)) {
      final owner = node['key'] as String;
      _identifier(owner);
      if (store.record('schedule', owner) == null) BackupLimits.invalid();
      final id = node['id'] as int;
      if (node['kind'] != 'array') BackupLimits.invalid();
      final preparation = _preparation(id, 'scheduleStep', owner, admit: true);
      store.addRecord(
        'schedulePreparation',
        owner,
        id,
        detail: _durationSum(preparation).toString(),
      );
    }
    final templates = store.requiredChild(root, 'templates', 'array');
    for (final node in store.children(templates)) {
      budget.admitValidated();
      final id = node['id'] as int;
      final template = _template(id, admit: true);
      store.addRecord('template', template.id, id);
      _templateCount++;
      if (_templateCount % 64 == 0) await Future<void>.delayed(Duration.zero);
    }
    if (version == 2) {
      await _validateRecurring(
        store.requiredChild(root, 'recurring', 'object'),
      );
    }
    await _validateScheduleRelations();
    await _validateOrdinals();
  }

  static const _scheduleFields = {
    'id',
    'name',
    'civilTime',
    'timeZoneId',
    'occurrenceOffsetSeconds',
    'moveTimeMinutes',
    'isChanged',
    'spareTimeMinutes',
    'note',
    'latenessTime',
    'doneStatus',
    'finishedAt',
    'startedAt',
    'preparationFrozen',
    'preparationMode',
    'preparationTemplateId',
    'preparationTemplateName',
    'preparationTemplateDeleted',
    'scoreContributionRecorded',
    'recurringSegmentId',
    'recurringSlotKey',
    'recurringOrdinal',
    'recurringOverrides',
    'preparationDefinitionId',
  };
  ScheduleEntity _schedule(int id) {
    final fields = store.fields(id, _scheduleFields);
    fields['place'] = store.fields(store.requiredChild(id, 'place', 'object'), {
      'id',
      'name',
    });
    if (_collectTimeIssues) {
      for (final field in ['startedAt', 'finishedAt']) {
        final value = fields[field];
        if (value != null) {
          fields[field] = _reviewableInstant(
            id,
            field,
            value,
          ).toIso8601String();
        }
      }
    }
    try {
      return BackupContent.decodeScheduleStructure(fields);
    } on BackupProcessingFailure {
      rethrow;
    } on FormatException {
      rethrow;
    } on ArgumentError {
      BackupLimits.invalid();
    }
  }

  PreparationEntity _preparation(
    int id,
    String kind,
    String owner, {
    bool admit = false,
  }) {
    final steps = <Map<String, dynamic>>[];
    for (final node in store.children(id)) {
      if (steps.length == BackupLimits.preparationSteps) {
        BackupLimits.exceeded('preparationSteps');
      }
      if (admit) budget.admitValidated();
      final nodeId = node['id'] as int;
      final fields = store.fields(nodeId, {'id', 'name', 'minutes', 'nextId'});
      _identifier(fields['id']);
      _name(fields['name']);
      if (fields['nextId'] != null) _identifier(fields['nextId']);
      BackupLimits.minutes(fields['minutes']);
      if (admit) {
        store.addRecord(
          kind,
          fields['id'] as String,
          nodeId,
          owner: owner,
          reference: fields['nextId'] as String?,
        );
      }
      steps.add(fields);
    }
    // At most 1,000 steps, each with bounded ID/ref and <=30-character name.
    // The original graph is checked before ordered or any DAO can repair it.
    budget.visit(steps.length * 2);
    return BackupContent.decodePreparation(steps);
  }

  PreparationTemplateEntity _template(int id, {bool admit = false}) {
    final fields = store.fields(id, {'id', 'name', 'createdAt', 'updatedAt'});
    final identity = _identifier(fields['id']);
    _name(fields['name']);
    return PreparationTemplateEntity(
      id: identity,
      name: fields['name'] as String,
      createdAt: _collectTimeIssues
          ? _reviewableInstant(id, 'createdAt', fields['createdAt'])
          : _instant(fields['createdAt']),
      updatedAt: _collectTimeIssues
          ? _reviewableInstant(id, 'updatedAt', fields['updatedAt'])
          : _instant(fields['updatedAt']),
      preparation: _preparation(
        store.requiredChild(id, 'preparation', 'array'),
        'templateStep',
        identity,
        admit: admit,
      ),
    );
  }

  DateTime _instant(Object? value) {
    if (value is! String) BackupLimits.invalid();
    final instant = BackupValueValidation.instant(value);
    if (instant.microsecondsSinceEpoch % Duration.microsecondsPerSecond != 0) {
      throw const BackupProcessingFailure(
        BackupFailureKind.unsupportedRepresentation,
      );
    }
    return instant;
  }

  DateTime _reviewableInstant(int parent, String field, Object? value) {
    if (value is! String) BackupLimits.invalid();
    final civil = BackupValueValidation.date(value, civilTime: true);
    if (civil.microsecondsSinceEpoch % Duration.microsecondsPerSecond != 0) {
      throw const BackupProcessingFailure(
        BackupFailureKind.unsupportedRepresentation,
      );
    }
    if (BackupValueValidation.explicitOffset(value)) return _instant(value);
    _timeIssue(parent, field, BackupTimeIssueReason.missingInstantOffset);
    // A structural-only carrier preserves the presence of a started/frozen
    // fact while checking unrelated ownership/graphs. _validated remains false
    // while this issue exists, so it can never be materialized as an instant.
    return civil;
  }

  void _timeIssue(int parent, String field, BackupTimeIssueReason reason) {
    final id = '$parent:$field';
    if (store.record('timeIssue', id) != null) return;
    final node = store.child(parent, field);
    if (node == null) BackupLimits.invalid();
    store.addRecord(
      'timeIssue',
      id,
      node,
      owner: '$parent',
      reference: field,
      detail: reason.name,
    );
    timeIssueCount++;
  }

  String _identifier(Object? value) {
    if (value is! String || value.isEmpty) BackupLimits.invalid();
    BackupLimits.string(value, identifier: true);
    return value;
  }

  void _name(Object? value) {
    if (value is! String || value.isEmpty || value.length > 30) {
      BackupLimits.invalid();
    }
  }

  int _durationSum(PreparationEntity value) {
    var minutes = 0;
    for (final step in value.preparationStepList) {
      final addition = BackupLimits.minutes(step.preparationTime.inMinutes);
      if (addition > 0x7fffffffffffffff ~/ 60000000 - minutes) {
        BackupLimits.invalid();
      }
      minutes += addition;
    }
    return minutes;
  }

  void _uncertain(
    int node,
    DateTime civil,
    String zone,
    String? name, {
    BackupHistoryUncertaintyReason reason =
        BackupHistoryUncertaintyReason.historicalProvenance,
  }) {
    if (store.record('uncertainty', '$node') != null) return;
    store.addRecord('uncertainty', '$node', node);
    uncertainHistoryCount++;
    if (_uncertainExamples.length < 5) {
      _uncertainExamples.add(
        BackupHistoryUncertainty(
          name: name,
          civil: civil,
          zone: zone,
          reason: reason,
        ),
      );
    }
  }

  bool _validateTime(ScheduleEntity schedule, int node) {
    // Structure has been admitted separately. Unknown historical identifiers
    // are preserved; an unknown future never acquires a fallback zone.
    final knownZone = TimeZoneRules.contains(schedule.timeZoneId);
    final civil = schedule.scheduleTime;
    final offset = schedule.occurrenceOffsetSeconds;
    final explicitInstant = offset == null
        ? null
        : civil.subtract(Duration(seconds: offset));
    if (explicitInstant != null &&
        (explicitInstant.year < 1 || explicitInstant.year > 9999)) {
      BackupLimits.invalid();
    }
    final historical =
        RecurrenceReferencePolicy.hasProtectedFacts(schedule) ||
        (explicitInstant?.isBefore(nowUtc) ?? false) ||
        (offset == null &&
            civil.add(const Duration(hours: 24)).isBefore(nowUtc));
    if (historical) {
      if (offset == null || !knownZone) {
        _uncertain(
          node,
          civil,
          schedule.timeZoneId,
          schedule.scheduleName,
          reason: knownZone
              ? BackupHistoryUncertaintyReason.historicalProvenance
              : schedule.startedAt != null &&
                    schedule.preparationFrozen &&
                    schedule.doneStatus == ScheduleDoneStatus.notEnded
              ? BackupHistoryUncertaintyReason.protectedStartZone
              : BackupHistoryUncertaintyReason.unavailableHistoricalZone,
        );
      }
      return true; // Current tzdb cannot disprove a preserved historical occurrence.
    }
    if (!knownZone) {
      if (_collectTimeIssues) {
        _timeIssue(node, 'civilTime', BackupTimeIssueReason.unknownZone);
        return false;
      }
      throw const BackupProcessingFailure(
        BackupFailureKind.timeZoneChoiceRequired,
      );
    }
    final candidates = offsetLookup(civil, schedule.timeZoneId, budget);
    if (offset == null &&
        candidates.isNotEmpty &&
        candidates.every(
          (candidate) =>
              civil.subtract(Duration(seconds: candidate)).isBefore(nowUtc),
        )) {
      _uncertain(node, civil, schedule.timeZoneId, schedule.scheduleName);
      return true; // Preserve original null; this is an interpretation, not proof.
    }
    if (candidates.isEmpty ||
        (candidates.length > 1 && !candidates.contains(offset))) {
      if (_collectTimeIssues) {
        _timeIssue(
          node,
          'civilTime',
          candidates.isEmpty
              ? BackupTimeIssueReason.nonexistentCivil
              : BackupTimeIssueReason.repeatedCivil,
        );
        return false;
      }
      throw const BackupProcessingFailure(
        BackupFailureKind.timeZoneChoiceRequired,
      );
    }
    if (offset != null &&
        candidates.length == 1 &&
        candidates.single != offset) {
      if (_collectTimeIssues) {
        _timeIssue(node, 'civilTime', BackupTimeIssueReason.changedOffset);
      } else {
        throw const BackupProcessingFailure(
          BackupFailureKind.timeZoneChoiceRequired,
        );
      }
    }
    return false;
  }

  Future<void> _validateRecurring(int root) async {
    // Implemented as per-record scalar decode plus disk-indexed ownership below;
    // no full RecurringBackupData/maps or expansion of an infinite series.
    for (final kind in ['definitions', 'steps', 'segments', 'exclusions']) {
      final array = store.requiredChild(root, kind, 'array');
      var count = 0;
      for (final node in store.children(array)) {
        budget.admitValidated();
        final id = node['id'] as int;
        switch (kind) {
          case 'definitions':
            final value = _definition(id);
            store.addRecord(
              'definition',
              value.id,
              id,
              owner: value.ownerId,
              detail: value.scope,
            );
          case 'steps':
            final value = _definitionStep(id);
            store.addRecord(
              'definitionStep',
              value.id,
              id,
              owner: value.definitionId,
              position: value.position,
            );
          case 'segments':
            final value = _segment(id);
            store.addRecord(
              'segment',
              value.id,
              id,
              owner: value.seriesId,
              reference: value.preparationId,
            );
            await _spec(value);
          case 'exclusions':
            final value = _exclusion(id);
            store.addRecord(
              'exclusion',
              '$id',
              id,
              reference: value.segmentId,
              slot: _civil(value.slotKey).toIso8601String(),
              ordinal: value.ordinal,
            );
            store.addRecord(
              'occurrence',
              'exclusion:$id',
              id,
              reference: value.segmentId,
              slot: _civil(value.slotKey).toIso8601String(),
              ordinal: value.ordinal,
              owner: 'exclusion',
              detail:
                  _civil(
                    value.slotKey,
                  ).add(const Duration(hours: 24)).isBefore(nowUtc)
                  ? 'past'
                  : 'future',
            );
        }
        if (++count % 64 == 0) await Future<void>.delayed(Duration.zero);
      }
    }
    for (final definition in store.records('definition')) {
      final positions = <int>{};
      var totalMinutes = 0;
      for (final step in store.records(
        'definitionStep',
        owner: definition['identity'] as String,
      )) {
        if (positions.length == BackupLimits.preparationSteps) {
          BackupLimits.exceeded('preparationSteps');
        }
        if (!positions.add(step['position'] as int)) BackupLimits.invalid();
        final minutes = _definitionStep(step['node'] as int).minutes;
        if (minutes > 0x7fffffffffffffff ~/ 60000000 - totalMinutes) {
          BackupLimits.invalid();
        }
        totalMinutes += minutes;
      }
      if (positions.isEmpty ||
          positions.any((p) => p < 0 || p >= positions.length)) {
        BackupLimits.invalid();
      }
      store.addRecord(
        'definitionSum',
        definition['identity'] as String,
        definition['node'] as int,
        detail: '$totalMinutes',
      );
    }
    for (final step in store.records('definitionStep')) {
      if (store.record('definition', step['owner'] as String) == null) {
        BackupLimits.invalid();
      }
    }
    for (final segment in store.records('segment')) {
      final definition = store.record(
        'definition',
        segment['reference'] as String,
      );
      if (definition == null ||
          definition['detail'] != 'recurring' ||
          definition['owner'] != segment['owner']) {
        BackupLimits.invalid();
      }
    }
    for (final exclusion in store.records('exclusion')) {
      final segment = store.record('segment', exclusion['reference'] as String);
      if (segment == null) BackupLimits.invalid();
      await _validateSlot(
        _segment(segment['node'] as int),
        exclusion['slot'] as String,
        exclusion['ordinal'] as int,
        retainedReference: true,
      );
    }
  }

  PreparationDefinition _definition(int node) {
    final data = store.fields(node, {
      'id',
      'ownerId',
      'scope',
      'name',
      'createdAt',
    });
    _identifier(data['id']);
    _identifier(data['ownerId']);
    if (!{'recurring', 'occurrence', 'template'}.contains(data['scope'])) {
      BackupLimits.invalid();
    }
    if (data['name'] is! String) BackupLimits.invalid();
    _dbInstant(data['createdAt']);
    try {
      return PreparationDefinition.fromJson(data);
    } catch (_) {
      BackupLimits.invalid();
    }
  }

  PreparationDefinitionStep _definitionStep(int node) {
    final data = store.fields(node, {
      'id',
      'definitionId',
      'name',
      'minutes',
      'position',
    });
    _identifier(data['id']);
    _identifier(data['definitionId']);
    _name(data['name']);
    BackupLimits.integer(data['minutes'], maximum: 1440);
    BackupLimits.integer(data['position']);
    try {
      return PreparationDefinitionStep.fromJson(data);
    } catch (_) {
      BackupLimits.invalid();
    }
  }

  RecurringScheduleSegment _segment(int node) {
    final data = store.fields(node, {
      'id',
      'seriesId',
      'ruleJson',
      'scheduleJson',
      'preparationId',
      'fromSlot',
      'beforeSlot',
      'createdAt',
      'preparationNotBefore',
    });
    _identifier(data['id']);
    _identifier(data['seriesId']);
    _identifier(data['preparationId']);
    if (data['ruleJson'] is! String || data['scheduleJson'] is! String) {
      BackupLimits.invalid();
    }
    _civil(data['fromSlot']);
    if (data['beforeSlot'] != null &&
        _civil(data['beforeSlot']).isBefore(_civil(data['fromSlot']))) {
      BackupLimits.invalid();
    }
    _dbInstant(data['createdAt']);
    if (data['preparationNotBefore'] != null) {
      _dbInstant(data['preparationNotBefore']);
    }
    try {
      return RecurringScheduleSegment.fromJson(data);
    } catch (_) {
      BackupLimits.invalid();
    }
  }

  RecurringScheduleExclusion _exclusion(int node) {
    final data = store.fields(node, {'segmentId', 'slotKey', 'ordinal'});
    _identifier(data['segmentId']);
    _civil(data['slotKey']);
    BackupLimits.integer(data['ordinal'], minimum: 1);
    try {
      return RecurringScheduleExclusion.fromJson(data);
    } catch (_) {
      BackupLimits.invalid();
    }
  }

  DateTime _civil(Object? value) {
    if (value is! String) BackupLimits.invalid();
    return BackupValueValidation.date(value, civilTime: true);
  }

  void _dbInstant(Object? value) {
    final millis = BackupLimits.integer(
      value,
      minimum: -62135596800000,
      maximum: 253402300799000,
    );
    if (millis % 1000 != 0) {
      throw const BackupProcessingFailure(
        BackupFailureKind.unsupportedRepresentation,
      );
    }
  }

  Future<void> _validateSlot(
    RecurringScheduleSegment segment,
    String key,
    int ordinal, {
    bool retainedReference = false,
  }) async {
    budget.visit();
    final slot = _civil(key);
    if (slot.isBefore(_civil(segment.fromSlot)) ||
        (!retainedReference &&
            segment.beforeSlot != null &&
            !slot.isBefore(_civil(segment.beforeSlot)))) {
      BackupLimits.invalid();
    }
    BackupLimits.integer(ordinal, minimum: 1);
    final rule = (await _spec(segment)).rule;
    if (rule.count != null && ordinal > rule.count!) BackupLimits.invalid();
    if (slot.isBefore(rule.start) ||
        (rule.until != null &&
            RecurrenceRule.civilDate(slot).isAfter(rule.until!))) {
      BackupLimits.invalid();
    }
    if (slot.hour != rule.start.hour ||
        slot.minute != rule.start.minute ||
        slot.second != rule.start.second ||
        slot.millisecond != rule.start.millisecond ||
        slot.microsecond != rule.start.microsecond) {
      BackupLimits.invalid();
    }
    final days = RecurrenceRule.civilDate(
      slot,
    ).difference(RecurrenceRule.civilDate(rule.start)).inDays;
    switch (rule.frequency) {
      case RecurrenceFrequency.daily:
        if (days % rule.interval != 0) BackupLimits.invalid();
      case RecurrenceFrequency.weekly:
        final startWeek = RecurrenceRule.civilDate(
          rule.start,
        ).subtract(Duration(days: rule.start.weekday - 1));
        if (!rule.weekdays.contains(slot.weekday) ||
            RecurrenceRule.civilDate(slot).difference(startWeek).inDays ~/
                    7 %
                    rule.interval !=
                0) {
          BackupLimits.invalid();
        }
      case RecurrenceFrequency.monthly:
        final months =
            (slot.year - rule.start.year) * 12 + slot.month - rule.start.month;
        if (months % rule.interval != 0) BackupLimits.invalid();
        final last = DateTime.utc(slot.year, slot.month + 1, 0).day;
        switch (rule.monthly) {
          case MonthlyRecurrence.dayOfMonth:
            if (slot.day != rule.monthDay) BackupLimits.invalid();
          case MonthlyRecurrence.lastDay:
            if (slot.day != last) BackupLimits.invalid();
          case MonthlyRecurrence.nthWeekday:
            if (slot.weekday != rule.monthWeekday ||
                (rule.ordinal == -1
                    ? slot.day + 7 <= last
                    : (slot.day - 1) ~/ 7 + 1 != rule.ordinal)) {
              BackupLimits.invalid();
            }
        }
    }
  }

  Future<_SegmentSpec> _spec(RecurringScheduleSegment segment) async {
    budget.visit();
    final cached = _specCache.remove(segment.id);
    if (cached != null) {
      _specCache[segment.id] = cached;
      return cached;
    }
    final ruleData = await _innerObject(segment.ruleJson);
    final schedule = await _innerObject(segment.scheduleJson);
    BackupValueValidation.zoneIdentifier(_identifier(ruleData['zone']));
    if (schedule['zone'] != ruleData['zone']) BackupLimits.invalid();
    final start = _civil(ruleData['start']);
    final weekdays = ruleData['weekdays'];
    if (weekdays is! List ||
        weekdays.length > 7 ||
        weekdays.any((d) => d is! int)) {
      BackupLimits.invalid();
    }
    if (weekdays.toSet().length != weekdays.length) BackupLimits.invalid();
    final RecurrenceRule rule;
    try {
      rule = RecurrenceRule(
        frequency: RecurrenceFrequency.values.byName(
          ruleData['frequency'] as String,
        ),
        start: start,
        timeZoneId: ruleData['zone'] as String,
        interval: BackupLimits.integer(ruleData['interval'], minimum: 1),
        weekdays: weekdays.cast<int>().toSet(),
        monthly: MonthlyRecurrence.values.byName(ruleData['monthly'] as String),
        monthDay: BackupLimits.integer(
          ruleData['monthDay'],
          minimum: 1,
          maximum: 31,
        ),
        ordinal: BackupLimits.integer(
          ruleData['ordinal'],
          minimum: -1,
          maximum: 5,
        ),
        monthWeekday: BackupLimits.integer(
          ruleData['monthWeekday'],
          minimum: 1,
          maximum: 7,
        ),
        count: ruleData['count'] == null
            ? null
            : BackupLimits.integer(ruleData['count'], minimum: 1),
        until: ruleData['until'] == null ? null : _civil(ruleData['until']),
        repeatedTime: ruleData['repeatedTime'] == null
            ? null
            : RepeatedCivilTime.values.byName(
                ruleData['repeatedTime'] as String,
              ),
      );
    } on BackupProcessingFailure {
      rethrow;
    } catch (_) {
      BackupLimits.invalid();
    }
    if (_civil(segment.fromSlot).isBefore(rule.start)) BackupLimits.invalid();
    _identifier(schedule['id']);
    _identifier(schedule['placeId']);
    _name(schedule['place']);
    if (schedule['name'] is! String ||
        (schedule['name'] as String).trim().isEmpty ||
        schedule['note'] is! String) {
      BackupLimits.invalid();
    }
    BackupLimits.string(schedule['note'] as String, note: true);
    final base = ScheduleEntity(
      id: schedule['id'] as String,
      place: PlaceEntity(
        id: schedule['placeId'] as String,
        placeName: schedule['place'] as String,
      ),
      scheduleName: schedule['name'] as String,
      scheduleTime: _civil(schedule['time']),
      timeZoneId: schedule['zone'] as String,
      occurrenceOffsetSeconds: schedule['offset'] == null
          ? null
          : BackupLimits.integer(
              schedule['offset'],
              minimum: -86400,
              maximum: 86400,
            ),
      moveTime: Duration(minutes: BackupLimits.minutes(schedule['move'])),
      scheduleSpareTime: schedule['spare'] == null
          ? null
          : Duration(minutes: BackupLimits.minutes(schedule['spare'])),
      scheduleNote: schedule['note'] as String,
      isChanged: false,
      isStarted: false,
    );
    final spec = _SegmentSpec(rule, base);
    if (!TimeZoneRules.contains(rule.timeZoneId) &&
        !RecurrenceReferencePolicy.hasNoFutureGeneration(
          rule: rule,
          fromSlot: _civil(segment.fromSlot),
          beforeSlot: segment.beforeSlot == null
              ? null
              : _civil(segment.beforeSlot),
          nowUtc: nowUtc,
        )) {
      if (_collectTimeIssues) {
        final recordNode = store.record('segment', segment.id)?['node'] as int?;
        // The segment's record is installed by the caller before this lookup.
        if (recordNode == null) BackupLimits.invalid();
        _timeIssue(recordNode, 'ruleJson', BackupTimeIssueReason.unknownZone);
      } else {
        throw const BackupProcessingFailure(
          BackupFailureKind.timeZoneChoiceRequired,
        );
      }
    }
    if (_specCache.length == 16) _specCache.remove(_specCache.keys.first);
    _specCache[segment.id] = spec;
    return spec;
  }

  Future<Map<String, dynamic>> _innerObject(String value) async {
    // ruleJson/scheduleJson are themselves bounded to 64KiB scalar input. This
    // small record decoder shares strict duplicate/depth/token accounting.
    BackupLimits.string(value);
    final sink = _SmallObjectSink();
    final root = await BackupJsonReader(
      sink,
      budget,
    ).read(Stream.value(utf8.encode(value)));
    final result = sink.nodes[root];
    if (result is! Map<String, dynamic>) BackupLimits.invalid();
    return result;
  }

  Future<void> _validateScheduleRelations() async {
    var count = 0;
    for (final record in store.records('schedule')) {
      final schedule = _schedule(record['node'] as int);
      final links = [
        schedule.recurringSegmentId,
        schedule.recurringSlotKey,
        schedule.recurringOrdinal,
      ];
      if (links.any((v) => v != null) && links.any((v) => v == null)) {
        BackupLimits.invalid();
      }
      if (schedule.preparationDefinitionId != null &&
          store.record('definition', schedule.preparationDefinitionId!) ==
              null) {
        BackupLimits.invalid();
      }
      if (schedule.recurringSegmentId != null) {
        final segment = store.record('segment', schedule.recurringSegmentId!);
        if (segment == null || schedule.preparationDefinitionId == null) {
          BackupLimits.invalid();
        }
        await _validateSlot(
          _segment(segment['node'] as int),
          schedule.recurringSlotKey!,
          schedule.recurringOrdinal!,
          retainedReference:
              RecurrenceReferencePolicy.hasProtectedFacts(schedule) ||
              store.record(
                    'occurrence',
                    'schedule:${schedule.id}',
                  )?['detail'] ==
                  'past',
        );
        if (store.recordAtSlot(
              'exclusion',
              schedule.recurringSegmentId!,
              _civil(schedule.recurringSlotKey!).toIso8601String(),
            ) !=
            null) {
          BackupLimits.invalid();
        }
        final source = await _spec(_segment(segment['node'] as int));
        final overrides = schedule.recurringOverrides
            .split(',')
            .where((s) => s.isNotEmpty)
            .toSet();
        final definition = store.record(
          'definition',
          schedule.preparationDefinitionId!,
        );
        if (definition == null) BackupLimits.invalid();
        if (!overrides.contains('preparation') &&
            schedule.preparationDefinitionId != segment['reference']) {
          BackupLimits.invalid();
        }
        if (overrides.contains('preparation') &&
            (definition['detail'] != 'occurrence' ||
                definition['owner'] != schedule.id)) {
          BackupLimits.invalid();
        }
        if (!overrides.contains('time') &&
            (schedule.scheduleTime != _civil(schedule.recurringSlotKey) ||
                schedule.timeZoneId != source.rule.timeZoneId)) {
          BackupLimits.invalid();
        }
        if (!overrides.contains('name') &&
            schedule.scheduleName != source.schedule.scheduleName) {
          BackupLimits.invalid();
        }
        if (!overrides.contains('place') &&
            schedule.place != source.schedule.place) {
          BackupLimits.invalid();
        }
        if (!overrides.contains('move') &&
            schedule.moveTime != source.schedule.moveTime) {
          BackupLimits.invalid();
        }
        if (!overrides.contains('spare') &&
            schedule.scheduleSpareTime != source.schedule.scheduleSpareTime) {
          BackupLimits.invalid();
        }
        if (!overrides.contains('note') &&
            schedule.scheduleNote != source.schedule.scheduleNote) {
          BackupLimits.invalid();
        }
      }
      const allowed = {
        'name',
        'time',
        'place',
        'move',
        'spare',
        'note',
        'preparation',
      };
      if (schedule.recurringOverrides
          .split(',')
          .where((s) => s.isNotEmpty)
          .any((s) => !allowed.contains(s))) {
        BackupLimits.invalid();
      }
      final preparation = store.record('schedulePreparation', schedule.id);
      final effectiveDefinition = schedule.preparationDefinitionId == null
          ? null
          : store.record('definitionSum', schedule.preparationDefinitionId!);
      final prepMinutes = effectiveDefinition != null
          ? int.parse(effectiveDefinition['detail'] as String)
          : preparation == null
          ? 0
          : int.parse(preparation['detail'] as String);
      var total = prepMinutes;
      for (final value in [
        schedule.moveTime.inMinutes,
        (schedule.scheduleSpareTime ?? Duration.zero).inMinutes,
      ]) {
        if (value > 0x7fffffffffffffff ~/ 60000000 - total) {
          BackupLimits.invalid();
        }
        total += value;
      }
      final civilMicros = schedule.scheduleTime.microsecondsSinceEpoch;
      final lower = DateTime.utc(1).microsecondsSinceEpoch;
      final upper = DateTime.utc(10000).microsecondsSinceEpoch - 1;
      final leadMicros = total * 60000000; // checked multiplication above
      if (leadMicros > civilMicros - lower) BackupLimits.invalid();
      final change = store.record('timezoneChange', schedule.id);
      final offset = change == null
          ? schedule.occurrenceOffsetSeconds
          : int.parse(change['detail'] as String);
      if (offset != null) {
        final instantMicros = civilMicros - offset * 1000000;
        if (instantMicros < lower ||
            instantMicros > upper ||
            leadMicros > instantMicros - lower) {
          BackupLimits.invalid();
        }
      }
      if (++count % 64 == 0) await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _validateOrdinals() async {
    for (final record in store.records('segment')) {
      final segment = _segment(record['node'] as int);
      final spec = await _spec(segment);
      final knownZone = TimeZoneRules.contains(spec.rule.timeZoneId);
      if (!knownZone) {
        _uncertain(
          record['node'] as int,
          spec.rule.start,
          spec.rule.timeZoneId,
          spec.schedule.scheduleName,
          reason: BackupHistoryUncertaintyReason.historicalOrdinal,
        );
      }
      final references = store.occurrences(segment.id).iterator;
      if (!references.moveNext()) continue;
      var expected = references.current;
      final last = store.lastOccurrence(segment.id)!;
      final definitionSum = store.record(
        'definitionSum',
        segment.preparationId,
      );
      if (definitionSum == null) BackupLimits.invalid();
      var leadMinutes = int.parse(definitionSum['detail'] as String);
      for (final amount in [
        spec.schedule.moveTime.inMinutes,
        spec.schedule.scheduleSpareTime?.inMinutes ?? 0,
      ]) {
        if (amount > 0x7fffffffffffffff ~/ 60000000 - leadMinutes) {
          BackupLimits.invalid();
        }
        leadMinutes += amount;
      }
      var previous = 0;
      var visited = 0;
      await for (final candidate in scanBackupRule(
        rule: spec.rule,
        through: _civil(last['slot']),
        budget: budget,
        leadTime: Duration(minutes: leadMinutes),
        preparationNotBefore: segment.preparationNotBefore,
        offsetLookup: knownZone
            ? offsetLookup
            : (civil, zone, budget) {
                budget.visit();
                return const <int>[];
              },
      )) {
        final wanted = _civil(expected['slot']);
        if (candidate.civil.isBefore(wanted)) continue;
        if (candidate.civil != wanted) BackupLimits.invalid();
        final ordinal = expected['ordinal'] as int;
        if (ordinal <= previous || ordinal > candidate.calendarOrdinal) {
          BackupLimits.invalid();
        }
        previous = ordinal;
        if (!candidate.eligible || ordinal != candidate.currentOrdinal) {
          final retainedTail = RecurrenceReferencePolicy.isClosedTail(
            expected['slot'] as String,
            segment.beforeSlot,
          );
          // Relation validation has already rejected unprotected future rows.
          // A retained tombstone/history cannot become executable by matching
          // the current timezone database's ordinal.
          if (expected['detail'] != 'past' && !retainedTail) {
            if (_collectTimeIssues) {
              _timeIssue(
                record['node'] as int,
                'ruleJson',
                BackupTimeIssueReason.recurrenceOrder,
              );
            } else {
              throw const BackupProcessingFailure(
                BackupFailureKind.timeZoneChoiceRequired,
              );
            }
          }
          store.addRecord(
            'uncertainOrdinal',
            expected['identity'] as String,
            expected['node'] as int,
          );
          _uncertain(
            expected['node'] as int,
            wanted,
            spec.rule.timeZoneId,
            expected['owner'] == 'schedule' && _uncertainExamples.length < 5
                ? _schedule(expected['node'] as int).scheduleName
                : null,
          );
        }
        if (++visited % 64 == 0) await Future<void>.delayed(Duration.zero);
        if (!references.moveNext()) {
          expected = const {};
          break;
        }
        expected = references.current;
      }
      if (expected.isNotEmpty) BackupLimits.invalid();
    }
  }

  Future<void> materialize(
    AppDatabase database, {
    required bool pendingCleanup,
  }) => database.transaction(
    () => _materialize(database, pendingCleanup: pendingCleanup),
  );

  Future<void> _materialize(
    AppDatabase database, {
    required bool pendingCleanup,
  }) async {
    if (!_validated) {
      throw StateError('Unauthenticated content cannot be materialized');
    }
    await metadata.writeTo(database, pendingCleanup: pendingCleanup);
    await database.preparationUserDao.createPreparationUser(
      _preparation(_default, 'userStep', localProfileId),
      localProfileId,
    );
    for (final row in store.records('definition')) {
      await database
          .into(database.preparationDefinitions)
          .insert(_definition(row['node'] as int).toCompanion(false));
    }
    for (final row in store.records('definitionStep')) {
      await database
          .into(database.preparationDefinitionSteps)
          .insert(_definitionStep(row['node'] as int).toCompanion(false));
    }
    for (final row in store.records('segment')) {
      await database
          .into(database.recurringScheduleSegments)
          .insert(_segment(row['node'] as int).toCompanion(false));
    }
    for (final row in store.records('exclusion')) {
      await database
          .into(database.recurringScheduleExclusions)
          .insert(_exclusion(row['node'] as int).toCompanion(false));
    }
    for (final row in store.records('schedule')) {
      final schedule = _schedule(row['node'] as int);
      // Backup civil values are strict wall-clock carriers. The runtime DAO's
      // local DateTime converter can normalize a foreign zone's valid DST-gap
      // reading, so the portable boundary writes the literal SQL column.
      final portable = schedule.toScheduleWithPlaceRow();
      await database
          .into(database.places)
          .insertOnConflictUpdate(portable.place.toCompanion(false));
      final columns = portable.schedule.toCompanion(false).toColumns(false);
      for (final field in [
        'requires_start_confirmation',
        'aggregate_incarnation',
        'aggregate_version',
        'last_mutation_id',
        'last_mutation_digest',
        'last_mutation_version',
      ]) {
        columns.remove(field);
      }
      final civil = schedule.scheduleTime.toIso8601String();
      columns['schedule_time'] = Variable<String>(
        civil.substring(0, civil.length - 1),
      );
      await database
          .into(database.schedules)
          .insert(RawValuesInsertable(columns));
      final change = store.record('timezoneChange', schedule.id);
      if (change != null ||
          (pendingCleanup &&
              schedule.doneStatus == ScheduleDoneStatus.notEnded)) {
        await (database.update(
          database.schedules,
        )..where((t) => t.id.equals(schedule.id))).write(
          SchedulesCompanion(
            occurrenceOffsetSeconds: change == null
                ? const Value.absent()
                : Value(int.parse(change['detail'] as String)),
            requiresStartConfirmation: Value(
              pendingCleanup &&
                  schedule.doneStatus == ScheduleDoneStatus.notEnded,
            ),
          ),
        );
      }
      final preparation = store.record('schedulePreparation', schedule.id);
      if (preparation != null) {
        await database.preparationScheduleDao.createPreparationSchedule(
          _preparation(preparation['node'] as int, 'scheduleStep', schedule.id),
          schedule.id,
        );
      }
    }
    for (final row in store.records('template')) {
      final template = _template(row['node'] as int);
      await database.preparationTemplateDao.restore(
        id: template.id,
        name: template.name,
        preparation: template.preparation,
        createdAt: template.createdAt,
        updatedAt: template.updatedAt,
      );
    }
  }

  Future<void> validateReadBack(
    AppDatabase database, {
    required bool pendingCleanup,
  }) async {
    if (!_validated) throw StateError('Cannot verify provisional content');
    final foreignKeys = await database
        .customSelect('SELECT * FROM pragma_foreign_key_check LIMIT 1')
        .get();
    final check = await database.customSelect('PRAGMA quick_check(1)').get();
    if (foreignKeys.isNotEmpty || check.single.data.values.single != 'ok') {
      BackupLimits.invalid();
    }
    final expectedCounts = {
      'users': 1,
      'places': store.recordCount('place'),
      'schedules': _scheduleCount,
      'preparation_users': store.recordCount('userStep'),
      'preparation_schedules': store.recordCount('scheduleStep'),
      'preparation_templates': _templateCount,
      'preparation_template_steps': store.recordCount('templateStep'),
      'preparation_definitions': store.recordCount('definition'),
      'preparation_definition_steps': store.recordCount('definitionStep'),
      'recurring_schedule_segments': store.recordCount('segment'),
      'recurring_schedule_exclusions': store.recordCount('exclusion'),
    };
    for (final entry in expectedCounts.entries) {
      budget.visit(entry.value);
      final actual =
          (await database
                  .customSelect('SELECT count(*) AS n FROM ${entry.key}')
                  .getSingle())
              .read<int>('n');
      if (actual != entry.value) BackupLimits.invalid();
    }
    final user = await database.select(database.users).getSingle();
    final profile = metadata.profile.valueOrNull!;
    if (user.id != localProfileId ||
        user.spareTime != profile.spareTime.inMinutes ||
        user.note != profile.note ||
        user.isOnboardingCompleted != profile.isOnboardingCompleted ||
        user.eligibleOutcomeCount != profile.eligibleOutcomeCount ||
        user.onTimeOutcomeCount != profile.onTimeOutcomeCount ||
        user.alarmsEnabled != metadata.alarmsEnabled ||
        user.alarmOffsetMinutes != metadata.alarmOffsetMinutes ||
        user.detailedNotificationContent !=
            metadata.detailedNotificationContent ||
        user.dataRevision != metadata.dataRevision + 1 ||
        user.restoreCleanupPending != pendingCleanup ||
        user.rejectLegacyDelivery != pendingCleanup) {
      BackupLimits.invalid();
    }
    _same(
      BackupContent.encodePreparation(
        _preparation(_default, 'userStep', localProfileId),
      ),
      BackupContent.encodePreparation(
        await database.preparationUserDao.getPreparationUsersByUserId(
          localProfileId,
        ),
      ),
    );
    for (final record in store.records('schedule')) {
      final expected = _schedule(record['node'] as int);
      final actualRow = await database.scheduleDao.getScheduleById(expected.id);
      final actual = actualRow.toScheduleEntity();
      final expectedJson = BackupContent.encodeSchedule(expected);
      final changed = store.record('timezoneChange', expected.id);
      if (changed != null) {
        expectedJson['occurrenceOffsetSeconds'] = int.parse(
          changed['detail'] as String,
        );
      }
      budget.visit(); // Additional bounded raw civil-column lookup.
      final actualJson = BackupContent.encodeSchedule(actual);
      actualJson['civilTime'] =
          (await database
                  .customSelect(
                    'SELECT schedule_time FROM schedules WHERE id = ?',
                    variables: [Variable<String>(expected.id)],
                  )
                  .getSingle())
              .read<String>('schedule_time');
      _same(_canonicalSchedule(expectedJson), _canonicalSchedule(actualJson));
      if (actual.isStarted ||
          actualRow.schedule.requiresStartConfirmation !=
              (pendingCleanup &&
                  expected.doneStatus == ScheduleDoneStatus.notEnded)) {
        BackupLimits.invalid();
      }
      final preparation = store.record('schedulePreparation', expected.id);
      if (preparation != null) {
        _same(
          BackupContent.encodePreparation(
            _preparation(
              preparation['node'] as int,
              'scheduleStep',
              expected.id,
            ),
          ),
          BackupContent.encodePreparation(
            await database.preparationScheduleDao
                .getPreparationSchedulesByScheduleId(expected.id),
          ),
        );
      }
    }
    for (final record in store.records('template')) {
      final expected = _template(record['node'] as int);
      final actual = await database.preparationTemplateDao.getById(expected.id);
      if (expected.id != actual.id ||
          expected.name != actual.name ||
          !expected.createdAt.isAtSameMomentAs(actual.createdAt) ||
          !expected.updatedAt.isAtSameMomentAs(actual.updatedAt)) {
        BackupLimits.invalid();
      }
      _same(
        BackupContent.encodePreparation(expected.preparation),
        BackupContent.encodePreparation(actual.preparation),
      );
    }
    for (final record in store.records('definition')) {
      final expected = _definition(record['node'] as int);
      final actual = await (database.select(
        database.preparationDefinitions,
      )..where((t) => t.id.equals(expected.id))).getSingle();
      _same(expected.toJson(), actual.toJson());
    }
    for (final record in store.records('definitionStep')) {
      final expected = _definitionStep(record['node'] as int);
      final actual = await (database.select(
        database.preparationDefinitionSteps,
      )..where((t) => t.id.equals(expected.id))).getSingle();
      _same(expected.toJson(), actual.toJson());
    }
    for (final record in store.records('segment')) {
      final expected = _segment(record['node'] as int);
      final actual = await (database.select(
        database.recurringScheduleSegments,
      )..where((t) => t.id.equals(expected.id))).getSingle();
      final left = expected.toJson();
      final right = actual.toJson();
      for (final key in [
        'rootSegmentId',
        'aggregateIncarnation',
        'aggregateVersion',
        'lastMutationId',
        'lastMutationDigest',
        'lastMutationVersion',
      ]) {
        left.remove(key);
        right.remove(key);
      }
      _same(left, right);
    }
    for (final record in store.records('exclusion')) {
      final expected = _exclusion(record['node'] as int);
      final actual =
          await (database.select(database.recurringScheduleExclusions)..where(
                (t) =>
                    t.segmentId.equals(expected.segmentId) &
                    t.slotKey.equals(expected.slotKey),
              ))
              .getSingle();
      _same(expected.toJson(), actual.toJson());
    }
  }

  Map<String, Object?> _canonicalSchedule(Map<String, Object?> value) {
    value['civilTime'] = _civil(value['civilTime']).toIso8601String();
    for (final field in ['startedAt', 'finishedAt']) {
      if (value[field] != null) {
        value[field] = BackupValueValidation.date(
          value[field] as String,
        ).toUtc().toIso8601String();
      }
    }
    return value;
  }

  void _same(Object? expected, Object? actual) {
    budget.visit();
    if (!const DeepCollectionEquality().equals(expected, actual)) {
      BackupLimits.invalid();
    }
  }

  Future<void> release() => store.release();
}

class _SegmentSpec {
  const _SegmentSpec(this.rule, this.schedule);
  final RecurrenceRule rule;
  final ScheduleEntity schedule;
}

class _SmallObjectSink implements BackupJsonSink {
  final nodes = <int, dynamic>{};
  @override
  int writeNode(int? parent, String? key, String kind, Object? scalar) {
    final dynamic value = kind == 'object'
        ? <String, dynamic>{}
        : kind == 'array'
        ? <dynamic>[]
        : scalar;
    final id = nodes.length + 1;
    if (parent != null) {
      final target = nodes[parent];
      if (target is Map<String, dynamic>) {
        if (target.containsKey(key)) BackupLimits.invalid();
        target[key!] = value;
      } else {
        (target as List).add(value);
      }
    }
    nodes[id] = value;
    return id;
  }
}
