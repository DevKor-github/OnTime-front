part of 'backup_validated_ingestion.dart';

extension _AuthenticatedRecurringReview on BackupAuthenticatedTimeReview {
  void _checkRecurringDraft(BackupRecurringTimeDraft draft) => _checkDraft(
    BackupTimeDraft(
      identity: draft.identity,
      revision: draft.revision,
      rulesIdentity: draft.rulesIdentity,
      issueId: draft.issueId,
      civil: CivilDateTime.fromFields(draft.rule.start),
      zone: draft.rule.timeZoneId,
    ),
  );

  Future<RecurrenceRule> _readRecurrenceRule(String issueId) async {
    _check();
    if (!_structureChecked) throw const BackupTimeReviewStale();
    final revision = _revision;
    final row = _store.record('timeIssue', issueId);
    if (row == null || row['reference'] != 'ruleJson') {
      throw const BackupTimeReviewStale();
    }
    final raw = _data._segment(int.parse(row['owner'] as String));
    final rule = (await _data._spec(raw)).rule;
    _check();
    if (!_structureChecked || revision != _revision) {
      throw const BackupTimeReviewStale();
    }
    return rule;
  }

  bool _protectedForPlan(ScheduleEntity value, DateTime now) =>
      RecurrenceReferencePolicy.hasProtectedFacts(value) ||
      value.startedAt != null ||
      value.finishedAt != null ||
      value.scoreContributionRecorded ||
      ScheduleTimeResolver.resolve(value, nowUtc: now).isHistorical ||
      RecurrenceReferencePolicy.isProvablyPast(value, now);

  Future<BackupRecurringTimePlan> _reviewRecurrence(
    BackupRecurringTimeDraft draft,
  ) async {
    _checkRecurringDraft(draft);
    final at = _now().toUtc();
    final issueRecord = _store.record('timeIssue', draft.issueId);
    if (issueRecord == null || issueRecord['reference'] != 'ruleJson') {
      throw const BackupTimeReviewStale();
    }
    final issue = _issue(issueRecord);
    final raw = _data._segment(int.parse(issueRecord['owner'] as String));
    final spec = await _data._spec(raw);
    BackupValueValidation.namedZone(draft.rule.timeZoneId);
    BackupLimits.string(jsonEncode(RecurrenceCodec.ruleToJson(draft.rule)));
    BackupLimits.integer(draft.rule.interval, minimum: 1);
    if (draft.rule.count != null) {
      BackupLimits.integer(draft.rule.count, minimum: 1);
    }
    final from = CivilDateTime.parse(raw.fromSlot).toUtcCarrier();
    final before = raw.beforeSlot == null
        ? null
        : CivilDateTime.parse(raw.beforeSlot!).toUtcCarrier();
    final allRows = <ScheduleEntity>[];
    for (final record in _store.records('schedule')) {
      final value = _data._schedule(record['node'] as int);
      if (value.recurringSegmentId == raw.id) allRows.add(value);
    }
    final futureRows =
        allRows.where((row) => !_protectedForPlan(row, at)).toList()
          ..sort((a, b) {
            final cmp = CivilDateTime.parse(
              a.recurringSlotKey!,
            ).compareTo(CivilDateTime.parse(b.recurringSlotKey!));
            if (cmp != 0) return cmp;
            final ordinal = a.recurringOrdinal!.compareTo(b.recurringOrdinal!);
            return ordinal == 0 ? a.id.compareTo(b.id) : ordinal;
          });
    final anchorRow = futureRows.firstOrNull;
    final anchor = BackupRecurringTimeAnchor(
      segmentId: raw.id,
      originalSlot: anchorRow == null
          ? from
          : CivilDateTime.parse(anchorRow.recurringSlotKey!).toUtcCarrier(),
      scheduleId: anchorRow?.id,
      originalOrdinal: anchorRow?.recurringOrdinal,
    );
    final unknown = !TimeZoneRules.contains(spec.rule.timeZoneId);
    final prefixSafe = RecurrenceReferencePolicy.hasNoFutureGeneration(
      rule: spec.rule,
      fromSlot: from,
      beforeSlot: anchor.originalSlot,
      nowUtc: at,
    );
    if (unknown && !prefixSafe && !draft.replaceWholeSourceInterval) {
      throw const BackupRecurringWholeReplacementRequired();
    }
    if (draft.replaceWholeSourceInterval && !unknown) {
      throw const RecurrenceValidationException(
        'Whole source replacement is only available for an unresolved source zone.',
      );
    }
    final closeAt = draft.replaceWholeSourceInterval
        ? from
        : anchor.originalSlot;
    if (before != null && !closeAt.isBefore(before)) {
      throw const BackupTimeReviewStale();
    }
    if (anchorRow == null &&
        (!draft.endExplicitlyChosen ||
            (draft.rule.count == null && draft.rule.until == null))) {
      throw const RecurringTimeCorrectionCountRequired();
    }
    final source = RecurringSegment(
      id: raw.id,
      seriesId: raw.seriesId,
      rule: spec.rule,
      schedule: spec.schedule,
      preparation: _data._definitionPreparation(raw.preparationId),
      preparationId: raw.preparationId,
      fromSlot: from,
      beforeSlot: before,
      createdAt: raw.createdAt,
      preparationNotBefore: raw.preparationNotBefore,
    );
    final exclusions = <TimeCorrectionExclusion>[];
    for (final value in _store.records('exclusion')) {
      if (value['reference'] == raw.id) {
        final row = _data._exclusion(value['node'] as int);
        exclusions.add(
          TimeCorrectionExclusion(row.segmentId, row.slotKey, row.ordinal),
        );
      }
    }
    final occurrenceOwners = <String, String>{};
    for (final value in _store.records('definition')) {
      if (value['detail'] == 'occurrence') {
        occurrenceOwners[value['identity'] as String] =
            value['owner'] as String;
      }
    }
    var mapping = await RecurringTimeCorrectionMapper.buildCandidate(
      anchor: anchor,
      closeAt: closeAt,
      wholeSource: draft.replaceWholeSourceInterval,
      segments: [source],
      schedules: allRows,
      exclusions: exclusions,
      occurrenceDefinitionOwners: occurrenceOwners,
      requested: draft.rule,
      endExplicitlyChosen: draft.endExplicitlyChosen,
      nowUtc: at,
      budget: _store.budget,
    );
    final unresolved = <String, ScheduleTimeResolutionStatus>{};
    for (final item in mapping.rows) {
      if (item.original.recurringOverrides.split(',').contains('time') ||
          item.detached) {
        final resolved = ScheduleTimeResolver.resolve(
          item.original,
          nowUtc: at,
        );
        if (resolved.instantUtc == null) {
          unresolved[item.original.id] = resolved.status;
        }
      }
    }
    TimeCorrectionConflictProof proof;
    if (unresolved.isEmpty) {
      proof = await _recurrenceProof(source, mapping, closeAt, at);
      if (draft.excludedConflictSlots.isNotEmpty) {
        final eligible = {
          for (final conflict in proof.conflicts.where(
            (e) => !e.persistent,
          )) ...[
            conflict.slot.key,
            if (conflict.otherSlotKey != null) conflict.otherSlotKey!,
          ],
        };
        if (!eligible.containsAll(draft.excludedConflictSlots)) {
          BackupLimits.invalid();
        }
        final selected = proof.proposedSlots
            .where((slot) => draft.excludedConflictSlots.contains(slot.key))
            .toList();
        if (selected.length != draft.excludedConflictSlots.length) {
          BackupLimits.invalid();
        }
        mapping = RecurringTimeCorrectionMapping(
          rule: mapping.rule,
          automaticallyRetainedCount: mapping.automaticallyRetainedCount,
          rows: [
            for (final item in mapping.rows)
              item.slot != null &&
                      draft.excludedConflictSlots.contains(item.slot!.key)
                  ? TimeCorrectionRowMapping(item.original, null)
                  : item,
          ],
          protectedRows: mapping.protectedRows,
          exclusions: mapping.exclusions,
          protectedSlots: mapping.protectedSlots,
          workUnits: _store.budget.work,
          firstSlot: mapping.firstSlot,
          conflictExclusions: selected,
        );
        proof = await _recurrenceProof(source, mapping, closeAt, at);
      }
    } else {
      if (draft.excludedConflictSlots.isNotEmpty) BackupLimits.invalid();
      // No claim of conflict safety: unresolved overrides block confirmation.
      proof = TimeCorrectionConflictProof(
        conflicts: [],
        through: mapping.rule.start,
        workUnits: _store.budget.work,
      );
    }
    _checkRecurringDraft(draft);
    if (_now().toUtc().isBefore(at)) throw const BackupTimeReviewStale();
    final plan = BackupRecurringTimePlan(
      draft: draft,
      issue: issue,
      anchor: anchor,
      originalRule: spec.rule,
      originalSchedule: spec.schedule,
      originalFrom: from,
      originalBefore: before,
      closeAt: closeAt,
      mapping: mapping,
      conflicts: proof,
      unresolvedOverrides: unresolved,
    );
    if (_recurringIssued.length == 20) {
      _recurringIssued.remove(_recurringIssued.keys.first);
    }
    _recurringIssued[plan] = at;
    return plan;
  }

  ScheduleEntity _mappedSchedule(
    TimeCorrectionRowMapping change,
    RecurrenceRule rule,
  ) =>
      change.detached ||
          change.original.recurringOverrides.split(',').contains('time')
      ? change.original
      : change.original.copyWith(
          scheduleTime: change.slot!.civilTime,
          timeZoneId: rule.timeZoneId,
          occurrenceOffsetSeconds: change.slot!.offsetSeconds,
        );

  Future<TimeCorrectionConflictProof> _recurrenceProof(
    RecurringSegment source,
    RecurringTimeCorrectionMapping mapping,
    DateTime closeAt,
    DateTime now,
  ) async {
    final world = await _BackupConflictWorld.read(
      _data,
      now,
      {
        for (final item in mapping.rows)
          if (!item.detached) item.original.id,
      },
      closingSegments: {source.id: closeAt},
    );
    final overrides = {
      for (final item in mapping.rows)
        if (!item.detached) item.slot!.key: _mappedSchedule(item, mapping.rule),
    };
    final proof = await TimeCorrectionConflictScanner.scan(
      rule: mapping.rule,
      base: source.schedule,
      basePreparation: source.preparation.totalDuration,
      proposedOverrides: overrides,
      proposedPreparationById: {
        for (final value in overrides.values)
          value.id: _data._effectivePreparation(value).totalDuration,
      },
      excludedSlots: {
        for (final slot in mapping.protectedSlots) slot.key,
        for (final slot in mapping.conflictExclusions) slot.key,
        for (final item in mapping.exclusions)
          if (item.slot != null) item.slot!.key,
      },
      storedOthers: world.rows,
      otherSegments: world.segments,
      otherExcludedSlots: world.exclusions,
      nowUtc: now,
      budget: _store.budget,
    );
    final start = proof.earliestPreparationUtc, end = proof.latestTargetUtc;
    if (start == null || end == null) {
      throw const RecurrenceValidationException(
        'The plan has no executable future occurrence.',
      );
    }
    return TimeCorrectionConflictProof(
      conflicts: proof.conflicts,
      through: proof.through,
      workUnits: _store.budget.work,
      proposedSlots: proof.proposedSlots,
      earliestPreparationUtc: start,
      latestTargetUtc: end,
      possibleOverlaps: [
        for (final item in [...world.possible, ...proof.possibleOverlaps])
          if (item.mayOverlap(start, end)) item,
      ],
    );
  }

  Object _recurringSemantics(BackupRecurringTimePlan plan) {
    Object? slot(RecurrenceSlot? value) => value == null
        ? null
        : [
            value.key,
            value.ordinal,
            value.offsetSeconds,
            value.instantUtc.microsecondsSinceEpoch,
          ];
    final map = plan.mapping;
    return [
      plan.anchor.segmentId,
      plan.anchor.scheduleId,
      plan.anchor.originalSlot,
      plan.anchor.originalOrdinal,
      plan.closeAt,
      RecurrenceCodec.ruleToJson(map.rule),
      map.automaticallyRetainedCount,
      slot(map.firstSlot),
      [
        for (final row in map.rows) [row.original, slot(row.slot)],
      ],
      map.protectedRows,
      [
        for (final value in map.exclusions)
          [
            value.original.segmentId,
            value.original.slot,
            value.original.ordinal,
            slot(value.slot),
          ],
      ],
      [for (final value in map.protectedSlots) slot(value)],
      [for (final value in map.conflictExclusions) slot(value)],
      plan.unresolvedOverrides,
      plan.conflicts.through,
      plan.conflicts.earliestPreparationUtc,
      plan.conflicts.latestTargetUtc,
      [for (final value in plan.conflicts.proposedSlots) slot(value)],
      [
        for (final value in plan.conflicts.possibleOverlaps)
          [
            value.id,
            value.reason,
            value.originalCivil,
            value.timeZoneId,
            value.rule == null ? null : RecurrenceCodec.ruleToJson(value.rule!),
            value.earliestPreparationUtc,
            value.latestTargetUtc,
          ],
      ],
      [
        for (final value in plan.conflicts.conflicts)
          [
            slot(value.slot),
            value.other.schedule,
            value.other.preparationStartUtc,
            value.other.instantUtc,
            value.otherSlotKey,
            value.persistent,
          ],
      ],
    ];
  }

  Future<void> _chooseRecurrence(BackupRecurringTimeChoice choice) async {
    final old = choice.plan, draft = choice.plan.draft;
    _checkRecurringDraft(draft);
    final issued = _recurringIssued[old];
    final oldBoundary = old.conflicts.earliestPreparationUtc;
    final chooseNow = _now().toUtc();
    if (issued == null ||
        chooseNow.isBefore(issued) ||
        oldBoundary == null ||
        !oldBoundary.isAfter(chooseNow)) {
      throw const BackupTimeReviewStale();
    }
    if (draft.replaceWholeSourceInterval &&
        !choice.confirmedWholeSourceReplacement) {
      throw const BackupTimeReviewStale();
    }
    if (!draft.replaceWholeSourceInterval &&
        choice.confirmedWholeSourceReplacement) {
      throw const BackupTimeReviewStale();
    }
    final plan = await _reviewRecurrence(draft);
    _checkRecurringDraft(draft);
    if (!const DeepCollectionEquality().equals(
      _recurringSemantics(old),
      _recurringSemantics(plan),
    )) {
      throw const BackupTimeReviewStale();
    }
    if (plan.unresolvedOverrides.isNotEmpty ||
        plan.conflicts.earliestPreparationUtc == null) {
      throw const BackupTimeReviewStale();
    }
    if (plan.conflicts.conflicts.isNotEmpty) {
      throw BackupTimeChoiceConflict(plan.conflicts);
    }
    final mapping = plan.mapping;
    final detached = {
      for (final item in mapping.rows)
        if (item.detached) item.original.id,
    };
    final unmatched = {
      for (final item in mapping.exclusions)
        if (item.slot == null)
          '${item.original.segmentId}\n${item.original.slot}',
    };
    if (!const SetEquality<String>().equals(
          detached,
          choice.confirmedDetachedIds,
        ) ||
        !const SetEquality<String>().equals(
          unmatched,
          choice.confirmedUnmatchedExclusions,
        ) ||
        !const SetEquality<String>().equals(
          plan.conflicts.possibleOverlaps.map((e) => e.id).toSet(),
          choice.acknowledgedPossibleIds,
        )) {
      throw const BackupTimeReviewStale();
    }
    final first = mapping.firstSlot;
    if (first == null) throw const BackupTimeReviewStale();
    final segmentRecord = _store.record('segment', plan.anchor.segmentId)!;
    final raw = _data._segment(segmentRecord['node'] as int);
    final at = _now().toUtc();
    final base = plan.originalSchedule.copyWith(
      scheduleTime: mapping.rule.start,
      timeZoneId: mapping.rule.timeZoneId,
      occurrenceOffsetSeconds: first.offsetSeconds,
    );
    final sourceLead =
        _data._definitionPreparation(raw.preparationId).totalDuration +
        base.moveTime +
        (base.scheduleSpareTime ?? Duration.zero);
    final boundaries = [
      oldBoundary,
      first.instantUtc.subtract(sourceLead),
      plan.conflicts.earliestPreparationUtc!,
    ];
    for (final item in mapping.rows) {
      final value = _mappedSchedule(item, mapping.rule);
      final resolved = ScheduleTimeResolver.resolve(value, nowUtc: at);
      if (resolved.instantUtc == null || resolved.isHistorical) {
        throw const BackupTimeReviewStale();
      }
      boundaries.add(resolved.instantUtc!.subtract(_data._leadFor(value)));
    }
    if (boundaries.any((time) => !time.isAfter(at))) {
      throw const BackupTimeReviewStale();
    }
    final newId = const Uuid().v4();
    final edits = <BackupRecurringScalarEdit>[];
    void edit(String kind, String id, int parent, String field, Object? value) {
      final node = _store.child(parent, field);
      edits.add(
        BackupRecurringScalarEdit(
          kind: kind,
          identity: id,
          parent: parent,
          field: field,
          expectedExists: node != null,
          expectedValue: node == null ? null : _store.scalar(node),
          value: value,
        ),
      );
    }

    edit(
      'segment',
      raw.id,
      segmentRecord['node'] as int,
      'beforeSlot',
      CivilDateTime.fromFields(plan.closeAt).toCivilIso8601String(),
    );
    for (final item in mapping.rows) {
      final value = _mappedSchedule(item, mapping.rule);
      final row = _store.record('schedule', value.id)!;
      final parent = row['node'] as int;
      final mask = value.recurringOverrides
          .split(',')
          .where((bit) => bit.isNotEmpty)
          .toSet();
      if (value.scheduleName != base.scheduleName) mask.add('name');
      if (value.place != base.place) mask.add('place');
      if (value.moveTime != base.moveTime) mask.add('move');
      if (value.scheduleSpareTime != base.scheduleSpareTime) mask.add('spare');
      if (value.scheduleNote != base.scheduleNote) mask.add('note');
      final fields = <String, Object?>{
        'recurringSegmentId': item.detached ? null : newId,
        'recurringSlotKey': item.slot?.key,
        'recurringOrdinal': item.slot?.ordinal,
        'recurringOverrides': item.detached
            ? ''
            : (mask.toList()..sort()).join(','),
        'civilTime': CivilDateTime.fromFields(
          value.scheduleTime,
        ).toCivilIso8601String(),
        'timeZoneId': value.timeZoneId,
        'occurrenceOffsetSeconds': value.occurrenceOffsetSeconds,
      };
      for (final entry in fields.entries) {
        edit('schedule', value.id, parent, entry.key, entry.value);
      }
    }
    final exclusions = {
      for (final slot in [
        ...mapping.protectedSlots,
        ...mapping.conflictExclusions,
        for (final entry in mapping.exclusions)
          if (entry.slot != null) entry.slot!,
      ])
        slot.key: slot,
    };
    final recurring = _store.child(_root, 'recurring')!;
    final claimNow = _now().toUtc();
    _checkRecurringDraft(draft);
    if (claimNow.isBefore(at) ||
        boundaries.any((time) => !time.isAfter(claimNow))) {
      throw const BackupTimeReviewStale();
    }
    _store.editRecurringTimePlan(
      segmentArray: _store.child(recurring, 'segments')!,
      exclusionArray: _store.child(recurring, 'exclusions')!,
      edits: edits,
      newSegment: {
        'id': newId,
        'seriesId': raw.seriesId,
        'preparationId': raw.preparationId,
        'fromSlot': CivilDateTime.fromFields(
          mapping.rule.start,
        ).toCivilIso8601String(),
        'beforeSlot': null,
        'createdAt': claimNow.millisecondsSinceEpoch,
        'preparationNotBefore': claimNow.millisecondsSinceEpoch,
        'ruleJson': jsonEncode(RecurrenceCodec.ruleToJson(mapping.rule)),
        'scheduleJson': jsonEncode(RecurrenceCodec.scheduleToJson(base)),
      },
      newExclusions: [
        for (final slot in exclusions.values)
          {'segmentId': newId, 'slotKey': slot.key, 'ordinal': slot.ordinal},
      ],
    );
    boundaries.sort();
    _confirmedBoundaries[draft.issueId] = boundaries.first;
    _revision++;
    _structureChecked = false;
    _issued.clear();
    _recurringIssued.clear();
  }
}
