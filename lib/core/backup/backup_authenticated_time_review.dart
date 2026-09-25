part of 'backup_validated_ingestion.dart';

/// Owns authenticated portable literals only. The callback can build a ready
/// staging database only after a fresh validator has checked the entire graph.
class BackupAuthenticatedTimeReview extends BackupTimeReviewInput
    implements BackupRecurringTimeReviewPort {
  BackupAuthenticatedTimeReview._(
    this._store,
    this._root,
    this._now,
    this._ready,
  );
  final BackupIngestionStore _store;
  final int _root;
  final DateTime Function() _now;
  final Future<BackupRestoreInput> Function(BackupValidatedIngestion) _ready;
  final String _identity = const Uuid().v4();
  int _revision = 0;
  late BackupValidatedIngestion _data;
  late String _rules;
  late DateTime _validationNow;
  Future<BackupRestoreSelection>? _flight;
  bool _disposed = false;
  bool _hasValidation = false;
  bool _structureChecked = false;
  final _confirmedBoundaries = <String, DateTime>{};
  bool _transferred = false;
  Future<void>? _disposal;
  final _issued = <BackupTimeFieldReview, DateTime>{};
  final _recurringIssued = <BackupRecurringTimePlan, DateTime>{};
  @override
  Future<RecurrenceRule> recurrenceRule(String issueId) =>
      _readRecurrenceRule(issueId);
  @override
  Future<BackupRecurringTimePlan> reviewRecurrence(
    BackupRecurringTimeDraft draft,
  ) => _reviewRecurrence(draft);
  @override
  Future<void> chooseRecurrence(BackupRecurringTimeChoice choice) =>
      _chooseRecurrence(choice);
  BackupProcessingLease get _lease => _store.budget.lease!;

  static Future<BackupRestoreSelection> decrypt({
    required Stream<List<int>> ciphertext,
    required String password,
    required BackupCrypto crypto,
    required BackupBudget budget,
    required Future<BackupIngestionStore> Function(BackupBudget) createStore,
    required DateTime Function() now,
    required Future<BackupRestoreInput> Function(BackupValidatedIngestion)
    ready,
  }) async {
    final store = await createStore(budget);
    BackupAuthenticatedTimeReview? owner;
    try {
      final root = await BackupJsonReader(store, budget, portableRecords: true)
          .read(
            crypto.decryptStream(
              container: ciphertext,
              password: password,
              budget: budget,
            ),
          );
      store.finish();
      owner = BackupAuthenticatedTimeReview._(store, root, now, ready);
      return await owner.revalidate();
    } catch (original) {
      try {
        if (owner == null) {
          await store.release();
        } else {
          await owner.dispose();
        }
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

  void _check({bool idle = true}) {
    if (_disposed || _transferred || (idle && _flight != null)) {
      throw const BackupTimeReviewStale();
    }
    _lease.check();
  }

  @override
  BackupTimeReviewSummary get summary => BackupTimeReviewSummary(
    identity: _identity,
    revision: _revision,
    validationNowUtc: _validationNow,
    rulesIdentity: _rules,
    issueCount: _data.timeIssueCount,
    independentStructureChecked: _structureChecked,
  );

  BackupTimeReviewIssue _issue(Map<String, Object?> row) {
    final parent = int.parse(row['owner'] as String);
    final field = row['reference'] as String;
    final literal = _store.scalar(row['node'] as int) as String;
    final path = _store.fieldPath(parent, field);
    final fields = _store.fields(parent, {
      'name',
      'timeZoneId',
      'occurrenceOffsetSeconds',
    });
    BackupTimeFieldKind kind;
    CivilDateTime civil;
    String? zone = fields['timeZoneId'] as String?;
    if (field == 'ruleJson') {
      final segment = _data._segment(parent);
      final spec = _data._specCache[segment.id];
      final rule = jsonDecode(literal) as Map<String, dynamic>;
      civil = CivilDateTime.parse(rule['start'] as String);
      zone = rule['zone'] as String;
      kind = BackupTimeFieldKind.recurrenceRule;
      return BackupTimeReviewIssue(
        id: row['identity'] as String,
        kind: kind,
        reason: BackupTimeIssueReason.values.byName(row['detail'] as String),
        fieldPath: path,
        name:
            spec?.schedule.scheduleName ??
            (jsonDecode(segment.scheduleJson) as Map<String, dynamic>)['name']
                as String,
        originalLiteral: _store.originalTimeScalar(parent, field) as String,
        currentLiteral: literal,
        civil: civil,
        zone: zone,
      );
    }
    civil = CivilDateTime.parse(literal);
    kind = switch (field) {
      'civilTime' => BackupTimeFieldKind.scheduleOccurrence,
      'startedAt' => BackupTimeFieldKind.scheduleStartedAt,
      'finishedAt' => BackupTimeFieldKind.scheduleFinishedAt,
      'createdAt' => BackupTimeFieldKind.templateCreatedAt,
      'updatedAt' => BackupTimeFieldKind.templateUpdatedAt,
      _ => throw const BackupTimeReviewStale(),
    };
    return BackupTimeReviewIssue(
      id: row['identity'] as String,
      kind: kind,
      reason: BackupTimeIssueReason.values.byName(row['detail'] as String),
      fieldPath: path,
      name: fields['name'] as String? ?? '',
      originalLiteral: _store.originalTimeScalar(parent, field) as String,
      currentLiteral: literal,
      civil: civil,
      zone: zone,
      selectedOffsetSeconds: fields['occurrenceOffsetSeconds'] as int?,
    );
  }

  @override
  Future<BackupTimeReviewIssuePage> issues({String? cursor}) async {
    _check();
    final after = cursor == null ? 0 : int.tryParse(cursor);
    if (after == null || after < 0) throw ArgumentError('Invalid issue cursor');
    if (!_structureChecked) throw const BackupTimeReviewStale();
    final rows = _store.timeIssuePage(after);
    return BackupTimeReviewIssuePage(
      rows.take(20).map(_issue).toList(),
      nextCursor: rows.length > 20 ? '${rows[19]['node']}' : null,
    );
  }

  void _checkDraft(BackupTimeDraft draft) {
    _check();
    if (!_structureChecked ||
        draft.identity != _identity ||
        draft.revision != _revision ||
        draft.rulesIdentity != _rules ||
        TimeZoneRules.loadedIdentity != _rules ||
        _now().toUtc().isBefore(_validationNow)) {
      throw const BackupTimeReviewStale();
    }
  }

  Future<TimeCorrectionConflictProof> _conflictProof(
    int parent,
    BackupTimeDraft draft,
    int offset,
    DateTime now,
  ) async {
    final stored = _data._schedule(parent);
    final desired = stored.copyWith(
      scheduleTime: draft.civil.toUtcCarrier(),
      timeZoneId: draft.zone,
      occurrenceOffsetSeconds: offset,
    );
    final instant = draft.civil.atOffset(offset);
    final lead = _data._leadFor(desired);
    if (!instant.subtract(lead).isAfter(now)) {
      throw const BackupTimeReviewStale();
    }
    final world = await _BackupConflictWorld.read(_data, now, {stored.id});
    final occurrences = CivilTimeResolver.resolve(
      draft.civil.toUtcCarrier(),
      draft.zone,
    );
    final rule = RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      start: draft.civil.toUtcCarrier(),
      timeZoneId: draft.zone,
      count: 1,
      repeatedTime: occurrences.length > 1
          ? occurrences.first.offsetSeconds == offset
                ? RepeatedCivilTime.first
                : RepeatedCivilTime.second
          : null,
    );
    final preparation = _data._effectivePreparation(stored).totalDuration;
    final proof = await TimeCorrectionConflictScanner.scan(
      rule: rule,
      base: desired,
      basePreparation: preparation,
      proposedOverrides: {rule.start.toIso8601String(): desired},
      proposedPreparationById: {desired.id: preparation},
      excludedSlots: {},
      storedOthers: world.rows,
      otherSegments: world.segments,
      otherExcludedSlots: world.exclusions,
      nowUtc: now,
      budget: _store.budget,
    );
    return TimeCorrectionConflictProof(
      conflicts: proof.conflicts,
      through: proof.through,
      workUnits: _store.budget.work,
      earliestPreparationUtc: instant.subtract(lead),
      latestTargetUtc: instant,
      possibleOverlaps: [...world.possible, ...proof.possibleOverlaps]
          .where((item) => item.mayOverlap(instant.subtract(lead), instant))
          .toList(),
    );
  }

  @override
  Future<BackupTimeFieldReview> review(BackupTimeDraft draft) async {
    _checkDraft(draft);
    final row = _store.record('timeIssue', draft.issueId);
    if (row == null) throw const BackupTimeReviewStale();
    final issue = _issue(row);
    if (issue.kind == BackupTimeFieldKind.recurrenceRule) {
      // Scalar editing cannot authorize graph/ordinal remapping.
      throw const BackupProcessingFailure(
        BackupFailureKind.timeZoneChoiceRequired,
      );
    }
    BackupValueValidation.namedZone(draft.zone);
    var choices = CivilTimeResolver.resolve(
      draft.civil.toUtcCarrier(),
      draft.zone,
    );
    final next = choices.isEmpty
        ? CivilTimeResolver.nextValidCivilTime(
            draft.civil.toUtcCarrier(),
            draft.zone,
          )
        : null;
    final conflicts = <int, TimeCorrectionConflictProof>{};
    final reviewedAt = _now().toUtc();
    if (issue.kind == BackupTimeFieldKind.scheduleOccurrence) {
      final lead = _data._leadFor(
        _data._schedule(int.parse(row['owner'] as String)),
      );
      choices = choices
          .where(
            (candidate) =>
                candidate.instantUtc.subtract(lead).isAfter(reviewedAt),
          )
          .toList();
      for (final candidate in choices) {
        conflicts[candidate.offsetSeconds] = await _conflictProof(
          int.parse(row['owner'] as String),
          draft,
          candidate.offsetSeconds,
          reviewedAt,
        );
      }
    }
    _checkDraft(draft);
    if (_now().toUtc().isBefore(reviewedAt)) {
      throw const BackupTimeReviewStale();
    }
    final value = BackupTimeFieldReview(
      draft: draft,
      issue: issue,
      choices: choices,
      conflictsByOffset: conflicts,
      nextValidCivil: next == null ? null : CivilDateTime.fromFields(next),
      previousInstantUtc: issue.selectedOffsetSeconds == null
          ? null
          : issue.civil.atOffset(issue.selectedOffsetSeconds!),
    );
    // Bound outstanding UI authority even when a caller repeatedly previews.
    if (_issued.length == 20) _issued.remove(_issued.keys.first);
    _issued[value] = _now().toUtc();
    return value;
  }

  @override
  Future<void> choose(BackupTimeChoice choice) async {
    final fieldReview = choice.review;
    final draft = fieldReview.draft;
    _checkDraft(draft);
    final issuedAt = _issued[fieldReview];
    final now = _now().toUtc();
    if (issuedAt == null || now.isBefore(issuedAt)) {
      throw const BackupTimeReviewStale();
    }
    final row = _store.record('timeIssue', draft.issueId);
    if (row == null) throw const BackupTimeReviewStale();
    final issue = _issue(row);
    final candidates = CivilTimeResolver.resolve(
      draft.civil.toUtcCarrier(),
      draft.zone,
    );
    final selected = candidates
        .where((value) => value.offsetSeconds == choice.offsetSeconds)
        .firstOrNull;
    if (selected == null) throw const BackupTimeReviewStale();
    final parent = int.parse(row['owner'] as String);
    final changes = <String, Object>{};
    DateTime? confirmedBoundary;
    if (issue.kind == BackupTimeFieldKind.scheduleOccurrence) {
      final schedule = _data._schedule(parent);
      final oldInstant = schedule.occurrenceOffsetSeconds == null
          ? null
          : CivilDateTime.fromFields(
              schedule.scheduleTime,
            ).atOffset(schedule.occurrenceOffsetSeconds!);
      if (schedule.startedAt != null ||
          schedule.preparationFrozen ||
          schedule.doneStatus != ScheduleDoneStatus.notEnded ||
          (oldInstant != null && !oldInstant.isAfter(now)) ||
          (oldInstant == null &&
              !schedule.scheduleTime
                  .add(const Duration(hours: 24))
                  .isAfter(now))) {
        throw const BackupTimeReviewStale();
      }
      final proof = await _conflictProof(
        parent,
        draft,
        choice.offsetSeconds,
        now,
      );
      _checkDraft(draft);
      final finalNow = _now().toUtc();
      final lead = _data._leadFor(schedule);
      if (finalNow.isBefore(now) ||
          !selected.instantUtc.subtract(lead).isAfter(finalNow)) {
        throw const BackupTimeReviewStale();
      }
      if (proof.conflicts.isNotEmpty ||
          !const SetEquality<String>().equals(
            proof.possibleOverlaps.map((item) => item.id).toSet(),
            choice.acknowledgedPossibleIds,
          )) {
        throw BackupTimeChoiceConflict(proof);
      }
      confirmedBoundary = selected.instantUtc.subtract(lead);
      changes.addAll({
        'civilTime': draft.civil.toCivilIso8601String(),
        'timeZoneId': draft.zone,
        'occurrenceOffsetSeconds': choice.offsetSeconds,
      });
      if (schedule.isRecurring) {
        final mask = {
          ...schedule.recurringOverrides
              .split(',')
              .where((value) => value.isNotEmpty),
          'time',
        }.toList()..sort();
        changes['recurringOverrides'] = mask.join(',');
      }
    } else {
      if (issue.reason != BackupTimeIssueReason.missingInstantOffset ||
          draft.civil != issue.civil) {
        throw const BackupTimeReviewStale();
      }
      changes[row['reference'] as String] = selected.instantUtc
          .toIso8601String();
    }
    _store.editTimeScalars([
      for (final entry in changes.entries)
        BackupTimeScalarEdit(
          parent: parent,
          field: entry.key,
          expectedExists: _store.child(parent, entry.key) != null,
          expectedValue: _store.child(parent, entry.key) == null
              ? null
              : _store.scalar(_store.child(parent, entry.key)!),
          value: entry.value,
        ),
    ]);
    if (confirmedBoundary != null) {
      _confirmedBoundaries[draft.issueId] = confirmedBoundary;
    }
    _revision++;
    _issued.clear();
    _recurringIssued.clear();
  }

  @override
  Future<BackupRestoreSelection> revalidate() async {
    _check();
    _lease.beginOperation();
    return _flight = _validateAndTransfer().whenComplete(() {
      _flight = null;
      _lease.endOperation();
    });
  }

  Future<BackupRestoreSelection> _validateAndTransfer() async {
    final nextNow = _now().toUtc();
    if ((_hasValidation && nextNow.isBefore(_validationNow)) ||
        _confirmedBoundaries.values.any((value) => !nextNow.isBefore(value))) {
      throw const BackupTimeReviewStale();
    }
    _structureChecked = false;
    _store.resetDerivedRecords();
    _validationNow = nextNow;
    _hasValidation = true;
    _rules = TimeZoneRules.loadedIdentity;
    _revision++;
    _issued.clear();
    _recurringIssued.clear();
    _data = BackupValidatedIngestion._(
      _store,
      _root,
      _validationNow,
      backupOffsets,
      true,
    );
    await _store.validateRecords(_data._validate);
    _check(idle: false);
    _structureChecked = true;
    if (_now().toUtc().isBefore(_validationNow) ||
        TimeZoneRules.loadedIdentity != _rules) {
      throw const BackupTimeReviewStale();
    }
    if (_data.timeIssueCount != 0) return this;
    _data._validated = true;
    _data.establishTimeAuthority(_rules);
    final ready = await _ready(_data);
    try {
      _check(idle: false);
      if (!_data.hasCurrentTimeAuthority(_now())) {
        throw const BackupTimeReviewStale();
      }
    } catch (original) {
      // The ready owner holds the newly allocated staging resources. Every
      // failed final check, including external cancellation, must retire it.
      _transferred = true;
      try {
        await ready.dispose();
      } catch (cleanup) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
    _transferred = true;
    return ready;
  }

  @override
  Future<void> dispose() {
    if (_transferred) return Future.value();
    return _disposal ??= _dispose().catchError((
      Object error,
      StackTrace stack,
    ) {
      // Keep the same cleanup owner, but do not cache a failed attempt forever.
      _disposal = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _dispose() async {
    _disposed = true;
    _issued.clear();
    _recurringIssued.clear();
    _lease.requestCancellation();
    final flight = _flight;
    if (flight != null) {
      try {
        await flight;
      } catch (_) {
        /* Cleanup remains owned below. */
      }
    }
    if (_transferred) return;
    if (_lease.phase == BackupProcessingPhase.cleanupPending) {
      await _lease.retryCleanup();
      return;
    }
    try {
      await _store.release();
    } catch (_) {
      _lease.retainCleanup(_store.release);
      rethrow;
    }
    _lease.release();
  }
}
