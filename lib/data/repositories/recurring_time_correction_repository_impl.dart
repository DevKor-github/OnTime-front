import 'dart:convert';
import 'time_correction_conflict_reader.dart';
import 'package:on_time_front/core/time/time_correction_conflicts.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_recurrence_scan.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/time/recurring_time_correction_mapping.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/mappers/recurrence_codec.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/recurrence/recurrence_reference_policy.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/repositories/recurring_schedule_repository.dart';
import 'package:on_time_front/domain/repositories/recurring_time_correction_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_aggregate_repository.dart';

/// A narrow time/rule plan over the finite materialized source. This repository
/// is exclusively for the active store: authenticated backup candidates use a
/// separate staging adapter and must never call this implementation.
@Singleton(as: RecurringTimeCorrectionRepository)
class RecurringTimeCorrectionRepositoryImpl
    implements RecurringTimeCorrectionRepository {
  RecurringTimeCorrectionRepositoryImpl(
    this.db,
    this.aggregates,
    this.recurring, {
    @ignoreParam LocalDataOperationGate? gate,
    @ignoreParam DateTime Function()? now,
  }) : gate = gate ?? LocalDataOperationGate.shared,
       now = now ?? DateTime.now;
  final AppDatabase db;
  final ScheduleAggregateRepository aggregates;
  final RecurringScheduleRepository recurring;
  final LocalDataOperationGate gate;
  final DateTime Function() now;
  static const _uuid = Uuid();

  Never _reject(ScheduleSaveFailure failure) =>
      throw ScheduleSaveRejected(failure);
  void _available() {
    if (!gate.isAvailable) _reject(ScheduleSaveFailure.unavailable);
  }

  @override
  bool isCurrent(ScheduleSaveReceipt receipt) =>
      gate.isAvailable && receipt.generation == gate.generation;

  String _hash(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();

  Future<_Source> _source(
    ScheduleEditSnapshot snapshot,
    BackupBudget budget,
  ) async {
    final segment = snapshot.segment;
    if (segment == null || snapshot.baseline.rootId == null) {
      _reject(ScheduleSaveFailure.invalid);
    }
    final segments =
        await (db.select(db.recurringScheduleSegments)
              ..where((t) => t.seriesId.equals(segment.seriesId))
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(BackupLimits.records + 1))
            .get();
    if (segments.length > BackupLimits.records) {
      BackupLimits.exceeded('records');
    }
    final joined = await db.scheduleDao.getSeriesReferences(
      segment.seriesId,
      limit: BackupLimits.schedules + 1,
    );
    if (joined.length > BackupLimits.schedules) {
      BackupLimits.exceeded('schedules');
    }
    final exclusions =
        await (db.select(db.recurringScheduleExclusions).join([
                innerJoin(
                  db.recurringScheduleSegments,
                  db.recurringScheduleSegments.id.equalsExp(
                    db.recurringScheduleExclusions.segmentId,
                  ),
                ),
              ])
              ..where(
                db.recurringScheduleSegments.seriesId.equals(segment.seriesId),
              )
              ..orderBy([
                OrderingTerm.asc(db.recurringScheduleExclusions.segmentId),
                OrderingTerm.asc(db.recurringScheduleExclusions.slotKey),
              ])
              ..limit(BackupLimits.records + 1))
            .get();
    budget.visit(segments.length + joined.length + exclusions.length);
    if (segments.length + joined.length + exclusions.length >
        BackupLimits.records) {
      BackupLimits.exceeded('records');
    }
    final definitions = <String, PreparationDefinition>{};
    final steps = <PreparationDefinitionStep>[];
    final preparations = <String, PreparationEntity>{};
    // Each unique definition is loaded once, and every retained step shares the
    // same logical budget as the calendar scans. No unbounded whole-app query.
    final ids = {
      for (final row in segments) row.preparationId,
      for (final row in joined)
        if (row.schedule.preparationDefinitionId != null)
          row.schedule.preparationDefinitionId!,
    }.toList()..sort();
    for (final id in ids) {
      budget.visit();
      final definition = await (db.select(
        db.preparationDefinitions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (definition == null) BackupLimits.invalid();
      definitions[id] = definition;
      final owned =
          await (db.select(db.preparationDefinitionSteps)
                ..where((t) => t.definitionId.equals(id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)])
                ..limit(BackupLimits.preparationSteps + 1))
              .get();
      if (owned.length > BackupLimits.preparationSteps) {
        BackupLimits.exceeded('preparationSteps');
      }
      budget.visit(owned.length);
      steps.addAll(owned);
      if (segments.length +
              joined.length +
              exclusions.length +
              definitions.length +
              steps.length >
          BackupLimits.records) {
        BackupLimits.exceeded('records');
      }
      preparations[id] = PreparationEntity(
        preparationStepList: [
          for (var i = 0; i < owned.length; i++)
            PreparationStepEntity(
              id: owned[i].id,
              preparationName: owned[i].name,
              preparationTime: Duration(minutes: owned[i].minutes),
              nextPreparationId: i + 1 < owned.length ? owned[i + 1].id : null,
            ),
        ],
      );
    }
    for (final row in segments) {
      final definition = definitions[row.preparationId]!;
      if (definition.scope != 'recurring' ||
          definition.ownerId != segment.seriesId) {
        BackupLimits.invalid();
      }
    }
    final byId = {for (final row in segments) row.id: row};
    for (final row in joined) {
      final schedule = row.schedule;
      final definition = definitions[schedule.preparationDefinitionId];
      if (definition == null) BackupLimits.invalid();
      if (schedule.recurringOverrides.split(',').contains('preparation')) {
        if (definition.scope != 'occurrence' ||
            definition.ownerId != schedule.id) {
          BackupLimits.invalid();
        }
      } else if (definition.id !=
          byId[schedule.recurringSegmentId]!.preparationId) {
        BackupLimits.invalid();
      }
    }
    return _Source(
      segments: [
        for (final row in segments)
          RecurringSegment(
            id: row.id,
            seriesId: row.seriesId,
            rule: RecurrenceCodec.ruleFromJson(jsonDecode(row.ruleJson)),
            schedule: RecurrenceCodec.scheduleFromJson(
              jsonDecode(row.scheduleJson),
            ),
            preparation: preparations[row.preparationId]!,
            preparationId: row.preparationId,
            fromSlot: CivilDateTime.parse(row.fromSlot).toUtcCarrier(),
            beforeSlot: row.beforeSlot == null
                ? null
                : CivilDateTime.parse(row.beforeSlot!).toUtcCarrier(),
            createdAt: row.createdAt,
            preparationNotBefore: row.preparationNotBefore,
          ),
      ],
      rows: joined.map((row) => row.toScheduleEntity()).toList(),
      exclusions: [
        for (final row in exclusions)
          TimeCorrectionExclusion(
            row.readTable(db.recurringScheduleExclusions).segmentId,
            row.readTable(db.recurringScheduleExclusions).slotKey,
            row.readTable(db.recurringScheduleExclusions).ordinal,
          ),
      ],
      preparations: preparations,
      occurrenceOwners: {
        for (final value in definitions.values)
          if (value.scope == 'occurrence') value.id: value.ownerId,
      },
      digest: _hash([
        segments.map((e) => e.toJson()).toList(),
        joined.map((e) => [e.schedule.toJson(), e.place.toJson()]).toList(),
        exclusions
            .map((e) => e.readTable(db.recurringScheduleExclusions).toJson())
            .toList(),
        definitions.values.map((e) => e.toJson()).toList(),
        steps.map((e) => e.toJson()).toList(),
      ]),
    );
  }

  Future<void> _authority(
    ScheduleEditSnapshot snapshot,
    RecurringTimeCorrectionRequest request,
    DateTime at,
    BackupBudget budget,
  ) async {
    final previous = request.anchorReview;
    if (snapshot.baseline != previous.snapshot.baseline ||
        previous.ruleIdentity != TimeZoneRules.loadedIdentity ||
        at.isBefore(previous.validationNowUtc)) {
      _reject(ScheduleSaveFailure.conflict);
    }
    final row = snapshot.schedule;
    final resolution = ScheduleTimeResolver.resolve(row, nowUtc: at);
    if (resolution != previous.resolution) {
      _reject(ScheduleSaveFailure.conflict);
    }
    if (snapshot.segment == null ||
        row.retainedRecurringReference ||
        RecurrenceReferencePolicy.hasProtectedFacts(row) ||
        row.startedAt != null ||
        row.finishedAt != null ||
        row.scoreContributionRecorded ||
        resolution.isHistorical ||
        RecurrenceReferencePolicy.isProvablyPast(row, at)) {
      _reject(ScheduleSaveFailure.protected);
    }
    switch (resolution.status) {
      case ScheduleTimeResolutionStatus.unknownZone:
      case ScheduleTimeResolutionStatus.nonexistent:
      case ScheduleTimeResolutionStatus.ambiguous:
      case ScheduleTimeResolutionStatus.changed:
        return;
      case ScheduleTimeResolutionStatus.historicalUncertain:
      case ScheduleTimeResolutionStatus.invalid:
        _reject(ScheduleSaveFailure.protected);
      case ScheduleTimeResolutionStatus.resolved:
        // A structurally valid stored ordinal can become stale while the
        // target's own offset remains valid. Verify that condition ourselves.
        final source = snapshot.segment!;
        BackupRuleCandidate? observed;
        final anchor = CivilDateTime.parse(
          row.recurringSlotKey!,
        ).toUtcCarrier();
        await for (final candidate in scanBackupRule(
          rule: source.rule,
          through: anchor,
          budget: budget,
          leadTime: source.leadTime,
          preparationNotBefore: source.preparationNotBefore,
        )) {
          if (candidate.civil == anchor) observed = candidate;
        }
        final staleOrdinal =
            observed == null ||
            !observed.eligible ||
            observed.currentOrdinal != row.recurringOrdinal;
        final lead =
            snapshot.preparation.totalDuration +
            row.moveTime +
            (row.scheduleSpareTime ?? Duration.zero);
        if (!staleOrdinal &&
            !resolution.instantUtc!.subtract(lead).isAfter(at)) {
          _reject(ScheduleSaveFailure.protected);
        }
    }
  }

  @override
  Future<RecurringTimeCorrectionReview> review(
    RecurringTimeCorrectionRequest request,
  ) => db.transaction(() async {
    _available();
    final at = now().toUtc();
    final budget = BackupBudget();
    final snapshot = await aggregates.readForEdit(
      request.anchorReview.snapshot.schedule.id,
    );
    await _authority(snapshot, request, at, budget);
    final source = await _source(snapshot, budget);
    var mapping = await RecurringTimeCorrectionMapper.build(
      anchor: snapshot.schedule,
      segments: source.segments,
      schedules: source.rows,
      exclusions: source.exclusions,
      occurrenceDefinitionOwners: source.occurrenceOwners,
      requested: request.rule,
      endExplicitlyChosen: request.endExplicitlyChosen,
      nowUtc: at,
      budget: budget,
    );
    final unresolved = <String, ScheduleTimeResolutionStatus>{};
    for (final row in mapping.rows) {
      if (row.original.recurringOverrides.split(',').contains('time')) {
        final time = ScheduleTimeResolver.resolve(row.original, nowUtc: at);
        if (time.instantUtc == null) unresolved[row.original.id] = time.status;
      }
    }
    TimeCorrectionConflictProof? proof;
    if (unresolved.isEmpty) {
      proof = await _proof(snapshot, source, mapping, at, budget);
      final excluded = request.excludedConflictSlots;
      if (excluded.isNotEmpty) {
        final eligible = {
          for (final conflict in proof.conflicts.where(
            (e) => !e.persistent,
          )) ...[
            conflict.slot.key,
            if (conflict.otherSlotKey != null) conflict.otherSlotKey!,
          ],
        };
        if (!eligible.containsAll(excluded)) {
          _reject(ScheduleSaveFailure.invalid);
        }
        final slots = proof.proposedSlots
            .where((e) => excluded.contains(e.key))
            .toList();
        if (slots.length != excluded.length) {
          _reject(ScheduleSaveFailure.invalid);
        }
        mapping = RecurringTimeCorrectionMapping(
          rule: mapping.rule,
          automaticallyRetainedCount: mapping.automaticallyRetainedCount,
          rows: [
            for (final row in mapping.rows)
              row.slot != null && excluded.contains(row.slot!.key)
                  ? TimeCorrectionRowMapping(row.original, null)
                  : row,
          ],
          protectedRows: mapping.protectedRows,
          exclusions: mapping.exclusions,
          protectedSlots: mapping.protectedSlots,
          workUnits: budget.work,
          firstSlot: mapping.firstSlot,
          conflictExclusions: slots,
        );
        // A materialized excluded row remains a standalone appointment. Re-read
        // it as an ordinary collision candidate; exclusion never deletes it.
        proof = await _proof(snapshot, source, mapping, at, budget);
      }
    } else if (request.excludedConflictSlots.isNotEmpty) {
      _reject(ScheduleSaveFailure.invalid);
    }
    final finalNow = now().toUtc();
    if (finalNow.isBefore(at)) _reject(ScheduleSaveFailure.conflict);
    await _authority(snapshot, request, finalNow, budget);
    _available();
    return RecurringTimeCorrectionReview(
      request: request,
      mapping: mapping,
      sourceDigest: source.digest,
      unresolvedOverrides: unresolved,
      conflictProof: proof,
    );
  });

  Future<TimeCorrectionConflictProof> _proof(
    ScheduleEditSnapshot snapshot,
    _Source source,
    RecurringTimeCorrectionMapping mapping,
    DateTime at,
    BackupBudget budget,
  ) async {
    final segment = snapshot.segment!;
    final world = await readTimeCorrectionConflictWorld(
      db: db,
      nowUtc: at,
      budget: budget,
      ignoredIds: {
        for (final row in mapping.rows)
          if (!row.detached) row.original.id,
      },
      closingSeriesAt: {
        segment.seriesId: CivilDateTime.parse(
          snapshot.schedule.recurringSlotKey!,
        ).toUtcCarrier(),
      },
    );
    final overrides = <String, ScheduleEntity>{};
    for (final row in mapping.rows.where((e) => !e.detached)) {
      final original = row.original;
      overrides[row.slot!.key] =
          original.recurringOverrides.split(',').contains('time')
          ? original
          : original.copyWith(
              scheduleTime: row.slot!.civilTime,
              timeZoneId: mapping.rule.timeZoneId,
              occurrenceOffsetSeconds: row.slot!.offsetSeconds,
            );
    }
    final proof = await TimeCorrectionConflictScanner.scan(
      rule: mapping.rule,
      base: segment.schedule,
      basePreparation: segment.preparation.totalDuration,
      proposedOverrides: overrides,
      proposedPreparationById: {
        for (final value in overrides.values)
          value.id:
              source.preparations[value.preparationDefinitionId]!.totalDuration,
      },
      excludedSlots: {
        for (final slot in mapping.protectedSlots) slot.key,
        for (final entry in mapping.exclusions)
          if (entry.slot != null) entry.slot!.key,
        for (final slot in mapping.conflictExclusions) slot.key,
      },
      storedOthers: world.rows,
      otherSegments: world.segments,
      otherExcludedSlots: world.exclusions,
      nowUtc: at,
      budget: budget,
    );
    final first = proof.earliestPreparationUtc!;
    final last = proof.latestTargetUtc!;
    return TimeCorrectionConflictProof(
      conflicts: proof.conflicts,
      through: proof.through,
      workUnits: budget.work,
      proposedSlots: proof.proposedSlots,
      earliestPreparationUtc: first,
      latestTargetUtc: last,
      possibleOverlaps: [
        for (final impact in [
          ...world.possibleOverlaps,
          ...proof.possibleOverlaps,
        ])
          if (impact.mayOverlap(first, last)) impact,
      ],
    );
  }

  String _digest(RecurringTimeCorrectionCommand command) => _hash([
    'recurring-time-correction-v1',
    command.review.request.anchorReview.snapshot.schedule.id,
    command.review.request.anchorReview.snapshot.baseline.props,
    command.review.request.anchorReview.ruleIdentity,
    command.review.request.anchorReview.validationNowUtc.toIso8601String(),
    command.review.sourceDigest,
    RecurrenceCodec.ruleToJson(command.review.request.rule),
    command.review.request.endExplicitlyChosen,
    command.review.request.excludedConflictSlots.toList()..sort(),
    command.acknowledgedUncertainIds.toList()..sort(),
    command.confirmedDetachedIds.toList()..sort(),
    command.confirmedUnmatchedExclusions.toList()..sort(),
  ]);

  @override
  Future<ScheduleSaveReceipt> confirm(
    RecurringTimeCorrectionCommand command,
  ) => db.transaction(() async {
    _available();
    final request = command.review.request;
    final expected = request.anchorReview.snapshot.baseline;
    final id = request.anchorReview.snapshot.schedule.id;
    final digest = _digest(command);
    final profile = await (db.select(
      db.users,
    )..where((t) => t.id.equals(localProfileId))).getSingle();
    final row = await (db.select(
      db.schedules,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (command.mutationId.isEmpty ||
        expected.incarnation == null ||
        expected.rootId == null) {
      _reject(ScheduleSaveFailure.invalid);
    }
    if (profile.storeIncarnation != expected.store ||
        gate.generation != expected.generation ||
        row == null ||
        row.aggregateIncarnation != expected.incarnation) {
      _reject(ScheduleSaveFailure.conflict);
    }
    final root = await (db.select(
      db.recurringScheduleSegments,
    )..where((t) => t.id.equals(expected.rootId!))).getSingleOrNull();
    if (root == null) _reject(ScheduleSaveFailure.conflict);
    if (row.lastMutationId == command.mutationId &&
        row.lastMutationDigest == digest &&
        row.lastMutationVersion == row.aggregateVersion &&
        root.lastMutationId == command.mutationId &&
        root.lastMutationDigest == digest &&
        root.lastMutationVersion == root.aggregateVersion) {
      return ScheduleSaveReceipt(
        scheduleId: id,
        mutationId: command.mutationId,
        generation: gate.generation,
        changed: false,
      );
    }
    if (row.lastMutationId == command.mutationId) {
      _reject(ScheduleSaveFailure.conflict);
    }
    if (root.lastMutationId == command.mutationId) {
      _reject(ScheduleSaveFailure.conflict);
    }
    // Recompute from actual rows. Client-supplied mapping objects and
    // diagnostic flags are never used as write authority.
    final fresh = await review(request);
    if (fresh.sourceDigest != command.review.sourceDigest ||
        fresh.unresolvedOverrides.isNotEmpty) {
      _reject(ScheduleSaveFailure.conflict);
    }
    final proof = fresh.conflictProof;
    if (proof == null) _reject(ScheduleSaveFailure.invalid);
    if (proof.conflicts.isNotEmpty) throw ScheduleTimeCorrectionConflict(proof);
    if (!const SetEquality<String>().equals(
      proof.possibleOverlaps.map((e) => e.id).toSet(),
      command.acknowledgedUncertainIds,
    )) {
      _reject(ScheduleSaveFailure.invalid);
    }
    final mapping = fresh.mapping;
    final detached = mapping.rows
        .where((e) => e.detached)
        .map((e) => e.original.id)
        .toSet();
    final unmatched = mapping.exclusions
        .where((e) => e.slot == null)
        .map((e) => '${e.original.segmentId}\n${e.original.slot}')
        .toSet();
    if (!const SetEquality<String>().equals(
          detached,
          command.confirmedDetachedIds,
        ) ||
        !const SetEquality<String>().equals(
          unmatched,
          command.confirmedUnmatchedExclusions,
        )) {
      _reject(ScheduleSaveFailure.invalid);
    }
    final snapshot = await aggregates.readForEdit(id);
    final source = snapshot.segment!;
    final first = mapping.firstSlot;
    if (first == null) _reject(ScheduleSaveFailure.invalid);
    final at = now().toUtc();
    final desired = <String, ScheduleEntity>{};
    for (final change in mapping.rows) {
      final original = change.original;
      final slot = change.slot;
      desired[original.id] =
          slot == null ||
              original.recurringOverrides.split(',').contains('time')
          ? original
          : original.copyWith(
              scheduleTime: slot.civilTime,
              timeZoneId: mapping.rule.timeZoneId,
              occurrenceOffsetSeconds: slot.offsetSeconds,
            );
    }
    final budget = BackupBudget()..visit(proof.workUnits);
    final preparations = <String, PreparationEntity>{};
    Future<void> validateFuture(DateTime finalNow) async {
      if (!first.instantUtc.subtract(source.leadTime).isAfter(finalNow)) {
        _reject(ScheduleSaveFailure.invalid);
      }
      for (final change in mapping.rows.where((e) => !e.detached)) {
        final value = desired[change.original.id]!;
        final resolution = ScheduleTimeResolver.resolve(
          value,
          nowUtc: finalNow,
        );
        final instant = resolution.instantUtc;
        final definition = value.preparationDefinitionId!;
        if (!preparations.containsKey(definition)) {
          final loaded = await recurring.getPreparation(definition);
          budget.visit(loaded.preparationStepList.length + 1);
          preparations[definition] = loaded;
        }
        budget.visit();
        final preparation = preparations[definition]!;
        final lead =
            preparation.totalDuration +
            value.moveTime +
            (value.scheduleSpareTime ?? Duration.zero);
        if (resolution.status != ScheduleTimeResolutionStatus.resolved ||
            resolution.isHistorical ||
            instant == null ||
            !instant.isAfter(finalNow) ||
            !instant.subtract(lead).isAfter(finalNow)) {
          _reject(ScheduleSaveFailure.invalid);
        }
      }
    }

    await validateFuture(at);
    final newId = _uuid.v7();
    final anchor = CivilDateTime.parse(
      snapshot.schedule.recurringSlotKey!,
    ).toUtcCarrier();
    final segments = await (db.select(
      db.recurringScheduleSegments,
    )..where((t) => t.seriesId.equals(source.seriesId))).get();
    for (final segment in segments) {
      final before = segment.beforeSlot == null
          ? null
          : CivilDateTime.parse(segment.beforeSlot!).toUtcCarrier();
      if (before != null && !before.isAfter(anchor)) continue;
      final from = CivilDateTime.parse(segment.fromSlot).toUtcCarrier();
      final boundary = from.isAfter(anchor) ? from : anchor;
      await (db.update(
        db.recurringScheduleSegments,
      )..where((t) => t.id.equals(segment.id))).write(
        RecurringScheduleSegmentsCompanion(
          beforeSlot: Value(
            CivilDateTime.fromFields(boundary).toCivilIso8601String(),
          ),
        ),
      );
    }
    // The base keeps its own non-time values; occurrence overrides retain
    // theirs. A time correction does not clone or re-own preparations.
    final base = source.schedule.copyWith(
      scheduleTime: mapping.rule.start,
      timeZoneId: mapping.rule.timeZoneId,
      occurrenceOffsetSeconds: first.offsetSeconds,
    );
    await db
        .into(db.recurringScheduleSegments)
        .insert(
          RecurringScheduleSegmentsCompanion.insert(
            id: newId,
            seriesId: source.seriesId,
            rootSegmentId: Value(expected.rootId),
            ruleJson: jsonEncode(RecurrenceCodec.ruleToJson(mapping.rule)),
            scheduleJson: jsonEncode(RecurrenceCodec.scheduleToJson(base)),
            preparationId: source.preparationId,
            fromSlot: CivilDateTime.fromFields(
              mapping.rule.start,
            ).toCivilIso8601String(),
            createdAt: at,
            preparationNotBefore: Value(at),
          ),
        );
    for (final change in mapping.rows) {
      final value = desired[change.original.id]!;
      final slot = change.slot;
      final overrides = value.recurringOverrides
          .split(',')
          .where((e) => e.isNotEmpty)
          .toSet();
      if (value.scheduleName != base.scheduleName) overrides.add('name');
      if (value.place != base.place) overrides.add('place');
      if (value.moveTime != base.moveTime) overrides.add('move');
      if (value.scheduleSpareTime != base.scheduleSpareTime) {
        overrides.add('spare');
      }
      if (value.scheduleNote != base.scheduleNote) overrides.add('note');
      await (db.update(
        db.schedules,
      )..where((t) => t.id.equals(value.id))).write(
        SchedulesCompanion(
          recurringSegmentId: Value(slot == null ? null : newId),
          recurringSlotKey: Value(slot?.key),
          recurringOrdinal: Value(slot?.ordinal),
          recurringOverrides: Value(
            slot == null ? '' : (overrides.toList()..sort()).join(','),
          ),
          scheduleTime: Value(value.scheduleTime),
          timeZoneId: Value(value.timeZoneId),
          occurrenceOffsetSeconds: Value(value.occurrenceOffsetSeconds),
        ),
      );
    }
    final exclusions = {
      ...mapping.protectedSlots,
      ...mapping.conflictExclusions,
      for (final exclusion in mapping.exclusions)
        if (exclusion.slot != null) exclusion.slot!,
    };
    for (final slot in exclusions) {
      await db
          .into(db.recurringScheduleExclusions)
          .insert(
            RecurringScheduleExclusionsCompanion.insert(
              segmentId: newId,
              slotKey: slot.key,
              ordinal: slot.ordinal,
            ),
          );
    }
    await db.userDao.markDurableDataChanged(localProfileId);
    final saved = await (db.select(
      db.schedules,
    )..where((t) => t.id.equals(id))).getSingle();
    await (db.update(db.schedules)..where((t) => t.id.equals(id))).write(
      SchedulesCompanion(
        lastMutationId: Value(command.mutationId),
        lastMutationDigest: Value(digest),
        lastMutationVersion: Value(saved.aggregateVersion),
      ),
    );
    final savedRoot = await (db.select(
      db.recurringScheduleSegments,
    )..where((t) => t.id.equals(expected.rootId!))).getSingle();
    await (db.update(
      db.recurringScheduleSegments,
    )..where((t) => t.id.equals(expected.rootId!))).write(
      RecurringScheduleSegmentsCompanion(
        lastMutationId: Value(command.mutationId),
        lastMutationDigest: Value(digest),
        lastMutationVersion: Value(savedRoot.aggregateVersion),
      ),
    );
    final finalNow = now().toUtc();
    if (finalNow.isBefore(at) ||
        finalNow.isBefore(request.anchorReview.validationNowUtc) ||
        request.anchorReview.ruleIdentity != TimeZoneRules.loadedIdentity ||
        gate.generation != expected.generation) {
      _reject(ScheduleSaveFailure.conflict);
    }
    await _authority(snapshot, request, finalNow, budget);
    await validateFuture(finalNow);
    final claimNow = now().toUtc();
    if (claimNow.isBefore(finalNow) ||
        TimeZoneRules.loadedIdentity != request.anchorReview.ruleIdentity) {
      _reject(ScheduleSaveFailure.conflict);
    }
    // These cached values need no await; the actual final clock reading
    // cannot reuse a selection after its preparation boundary has passed.
    if (!first.instantUtc.subtract(source.leadTime).isAfter(claimNow)) {
      _reject(ScheduleSaveFailure.invalid);
    }
    for (final change in mapping.rows.where((e) => !e.detached)) {
      final value = desired[change.original.id]!;
      final resolution = ScheduleTimeResolver.resolve(value, nowUtc: claimNow);
      final instant = resolution.instantUtc;
      final lead =
          preparations[value.preparationDefinitionId!]!.totalDuration +
          value.moveTime +
          (value.scheduleSpareTime ?? Duration.zero);
      if (resolution.isHistorical ||
          instant == null ||
          !instant.subtract(lead).isAfter(claimNow)) {
        _reject(ScheduleSaveFailure.invalid);
      }
    }
    _available();
    return ScheduleSaveReceipt(
      scheduleId: id,
      mutationId: command.mutationId,
      generation: gate.generation,
      changed: true,
    );
  });
}

final class _Source {
  const _Source({
    required this.segments,
    required this.rows,
    required this.exclusions,
    required this.occurrenceOwners,
    required this.digest,
    required this.preparations,
  });
  final List<RecurringSegment> segments;
  final List<ScheduleEntity> rows;
  final List<TimeCorrectionExclusion> exclusions;
  final Map<String, String> occurrenceOwners;
  final String digest;
  final Map<String, PreparationEntity> preparations;
}
