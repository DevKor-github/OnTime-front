import 'package:on_time_front/domain/entities/schedule_deletion.dart';
import 'package:on_time_front/data/daos/schedule_owned_content_cleanup.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/mappers/recurrence_codec.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/repositories/recurring_schedule_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_aggregate_repository.dart';
import 'package:on_time_front/domain/use-cases/schedule_form_submission.dart';
import 'package:uuid/uuid.dart';

@Singleton(as: ScheduleAggregateRepository)
class ScheduleAggregateRepositoryImpl implements ScheduleAggregateRepository {
  ScheduleAggregateRepositoryImpl(
    this.db,
    this.recurring, {
    @ignoreParam LocalDataOperationGate? gate,
    @ignoreParam DateTime Function()? now,
  }) : gate = gate ?? LocalDataOperationGate.shared,
       now = now ?? DateTime.now;
  final AppDatabase db;
  final RecurringScheduleRepository recurring;
  final LocalDataOperationGate gate;
  final DateTime Function() now;
  static const uuid = Uuid();

  @override
  bool isCurrent(ScheduleSaveReceipt receipt) =>
      !gate.isInvalidated &&
      !gate.isReplacingData &&
      gate.generation == receipt.generation;
  Future<User> _profile() => (db.select(
    db.users,
  )..where((t) => t.id.equals(localProfileId))).getSingle();
  @override
  Future<ScheduleEditBaseline> newBaseline() => db.transaction(() async {
    final profile = await _profile();
    return ScheduleEditBaseline(
      store: profile.storeIncarnation!,
      generation: gate.generation,
      revision: profile.dataRevision,
    );
  });
  @override
  Future<({ScheduleEditBaseline baseline, PreparationEntity preparation})>
  newDraft() => db.transaction(() async {
    final baseline = await newBaseline();
    final preparation = await db.preparationUserDao.getPreparationUsersByUserId(
      localProfileId,
    );
    return (baseline: baseline, preparation: preparation);
  });
  Future<RecurringScheduleSegment?> _root(
    String? segmentId, {
    String? seriesId,
  }) async {
    if (segmentId == null && seriesId == null) return null;
    final source = segmentId != null
        ? await (db.select(
            db.recurringScheduleSegments,
          )..where((t) => t.id.equals(segmentId))).getSingleOrNull()
        : await (db.select(db.recurringScheduleSegments)
                ..where((t) => t.seriesId.equals(seriesId!))
                ..limit(1))
              .getSingleOrNull();
    if (source?.rootSegmentId == null) return null;
    return (db.select(
      db.recurringScheduleSegments,
    )..where((t) => t.id.equals(source!.rootSegmentId!))).getSingleOrNull();
  }

  Future<PreparationEntity> preparationFor(ScheduleEntity schedule) =>
      readSchedulePreparation(db, schedule);
  @override
  Future<ScheduleEditSnapshot> readForEdit(String id) =>
      db.transaction(() async {
        final row = await db.scheduleDao.getScheduleById(id);
        final schedule = row.toScheduleEntity();
        final root = await _root(schedule.recurringSegmentId);
        final profile = await _profile();
        final preparation = await preparationFor(schedule);
        return ScheduleEditSnapshot(
          schedule,
          preparation,
          ScheduleEditBaseline(
            store: profile.storeIncarnation!,
            generation: gate.generation,
            revision: profile.dataRevision,
            incarnation: row.schedule.aggregateIncarnation,
            version: row.schedule.aggregateVersion,
            rootId: root?.id,
            rootIncarnation: root?.aggregateIncarnation,
            rootVersion: root?.aggregateVersion,
          ),
          segment: schedule.recurringSegmentId == null
              ? null
              : await recurring.getSegment(schedule.recurringSegmentId!),
        );
      });
  @override
  Future<ScheduleDeletionIntent> readForDeletion(
    String id, {
    RecurringEditScope scope = RecurringEditScope.occurrence,
  }) => db.transaction(() async {
    final generation = gate.captureWrite();
    final snapshot = await readForEdit(id);
    final targets = await _deletionTargets(snapshot, scope);
    gate.checkWrite(generation);
    return ScheduleDeletionIntent(
      intentId: uuid.v7(),
      snapshot: snapshot,
      scope: scope,
      targets: targets,
    );
  });

  Future<List<ScheduleDeletionTarget>> _deletionTargets(
    ScheduleEditSnapshot snapshot,
    RecurringEditScope scope,
  ) async {
    final selected = snapshot.schedule;
    if (selected.isStarted) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.protected);
    }
    final selectedTarget = ScheduleDeletionTarget(
      id: selected.id,
      incarnation: snapshot.baseline.incarnation!,
      version: snapshot.baseline.version!,
    );
    if (scope == RecurringEditScope.occurrence) return [selectedTarget];
    final evaluationNow = now().toUtc();
    bool protected(ScheduleEntity value) =>
        value.isStarted ||
        value.preparationFrozen ||
        value.doneStatus != ScheduleDoneStatus.notEnded ||
        !(ScheduleTimeResolver.resolve(
              value,
              nowUtc: evaluationNow,
            ).instantUtc?.isAfter(evaluationNow) ??
            false);
    if (!selected.isRecurring || protected(selected)) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.protected);
    }
    final segment = snapshot.segment!;
    final seriesIds = (await recurring.getSegments())
        .where((value) => value.seriesId == segment.seriesId)
        .map((value) => value.id)
        .toSet();
    final anchor = _civilSlot(selected.recurringSlotKey!);
    final targets = <ScheduleDeletionTarget>[];
    for (final row in await db.scheduleDao.getScheduleList()) {
      final value = row.toScheduleEntity();
      if (seriesIds.contains(value.recurringSegmentId) &&
          value.recurringSlotKey != null &&
          !_civilSlot(value.recurringSlotKey!).isBefore(anchor) &&
          !protected(value)) {
        targets.add(
          ScheduleDeletionTarget(
            id: value.id,
            incarnation: row.schedule.aggregateIncarnation!,
            version: row.schedule.aggregateVersion!,
          ),
        );
      }
    }
    return targets..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Future<ScheduleDeletionCommit> delete(
    ScheduleDeletionIntent intent,
  ) => db.writeTransaction(() async {
    final baseline = intent.snapshot.baseline;
    final profile = await _profile();
    if (profile.storeIncarnation != baseline.store ||
        gate.generation != baseline.generation) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
    }
    final id = intent.snapshot.schedule.id;
    final row = await (db.select(
      db.schedules,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return ScheduleDeletionCommit(
        scheduleId: id,
        store: baseline.store,
        generation: baseline.generation,
        removedIds: const {},
        changed: false,
        alreadyAbsent: true,
      );
    }
    final latest = await readForEdit(id);
    if (latest.baseline.incarnation != baseline.incarnation ||
        latest.baseline.version != baseline.version ||
        latest.baseline.rootIncarnation != baseline.rootIncarnation ||
        (intent.scope == RecurringEditScope.following &&
            latest.baseline.rootVersion != baseline.rootVersion)) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
    }
    final targets = await _deletionTargets(latest, intent.scope);
    if (targets.length != intent.targets.length ||
        List.generate(
          targets.length,
          (i) => targets[i] != intent.targets[i],
        ).any((different) => different)) {
      throw const ScheduleDeletionRejected(ScheduleDeletionFailure.conflict);
    }
    if (latest.schedule.isRecurring) {
      // This nested transaction owns the single durable revision change.
      await recurring.delete(latest.schedule, intent.scope);
    } else {
      await removeScheduleOwnedContent(db, id);
      await db.userDao.markDurableDataChanged(localProfileId);
    }
    return ScheduleDeletionCommit(
      scheduleId: id,
      store: baseline.store,
      generation: baseline.generation,
      removedIds: targets.map((value) => value.id).toSet(),
      changed: true,
      alreadyAbsent: false,
    );
  }, gate: gate);

  @override
  Future<bool> isDeletionCurrent(ScheduleDeletionCommit commit) =>
      db.transaction(() async {
        if (gate.isInvalidated ||
            gate.isReplacingData ||
            gate.isRecoveryPending ||
            gate.generation != commit.generation) {
          return false;
        }
        final profile = await _profile();
        if (profile.storeIncarnation != commit.store) return false;
        final ids = {...commit.removedIds, commit.scheduleId};
        final rows = await (db.select(
          db.schedules,
        )..where((t) => t.id.isIn(ids))).get();
        return rows.isEmpty &&
            gate.generation == commit.generation &&
            !gate.isInvalidated &&
            !gate.isReplacingData &&
            !gate.isRecoveryPending;
      });

  Never _reject(ScheduleSaveFailure value) => throw ScheduleSaveRejected(value);
  List<Object?> _steps(PreparationEntity p) => p.ordered.preparationStepList
      .map((s) => <Object?>[s.preparationName, s.preparationTime.inMinutes])
      .toList();
  SchedulePreparationMode _mode(ScheduleFormSubmission value) =>
      value.schedule.preparationMode ??
      (value.preparationChanged
          ? SchedulePreparationMode.custom
          : SchedulePreparationMode.defaultPreparation);
  List<Object?> _editable(ScheduleEntity s, SchedulePreparationMode mode) => [
    s.scheduleName,
    s.place.placeName,
    s.scheduleTime.toIso8601String(),
    s.timeZoneId,
    s.occurrenceOffsetSeconds,
    s.moveTime.inMicroseconds,
    s.scheduleSpareTime?.inMicroseconds,
    s.scheduleNote,
    mode.name,
    s.preparationTemplateId,
  ];
  String _digest(ScheduleFormSubmission v, bool editing) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            editing,
            v.baseline?.props,
            v.schedule.id,
            _editable(v.schedule, _mode(v)),
            _steps(v.preparation),
            v.recurrenceRule == null
                ? null
                : RecurrenceCodec.ruleToJson(v.recurrenceRule!),
            v.recurringScope.name,
            v.recurrenceCountChanged,
            (v.excludedSlots.toList()..sort()),
            v.confirmDetached,
            v.reviewedFirstSlotKey,
          ]),
        ),
      )
      .toString();
  bool _receipt(
    String? id,
    String? digest,
    int? version,
    int? receiptVersion,
    String wantedId,
    String wantedDigest,
  ) => id == wantedId && digest == wantedDigest && version == receiptVersion;
  void _validate(ScheduleFormSubmission v) {
    final s = v.schedule;
    if (s.scheduleName.trim().isEmpty ||
        s.place.placeName.trim().isEmpty ||
        s.moveTime.isNegative ||
        (s.scheduleSpareTime?.isNegative ?? false)) {
      _reject(ScheduleSaveFailure.invalid);
    }
    final mode = _mode(v);
    if (mode == SchedulePreparationMode.template &&
        s.preparationTemplateId == null) {
      _reject(ScheduleSaveFailure.invalid);
    }
    if (mode != SchedulePreparationMode.template &&
        s.preparationTemplateId != null) {
      _reject(ScheduleSaveFailure.invalid);
    }
    if (mode == SchedulePreparationMode.custom ||
        v.recurrenceRule != null ||
        s.preparationDefinitionId != null) {
      final steps = v.preparation.preparationStepList;
      final ids = steps.map((s) => s.id).toSet();
      final targets = steps
          .map((s) => s.nextPreparationId)
          .whereType<String>()
          .toList();
      if (targets.any((id) => !ids.contains(id)) ||
          targets.toSet().length != targets.length) {
        _reject(ScheduleSaveFailure.invalid);
      }
      for (final start in steps) {
        final seen = <String>{};
        var node = start;
        while (true) {
          if (!seen.add(node.id)) _reject(ScheduleSaveFailure.invalid);
          if (node.nextPreparationId == null) break;
          node = steps.firstWhere((s) => s.id == node.nextPreparationId);
        }
      }

      if (steps.isEmpty ||
          steps.map((s) => s.id).toSet().length != steps.length ||
          steps.any(
            (s) =>
                s.preparationName.trim().isEmpty ||
                s.preparationName.length > 30 ||
                s.preparationTime.inMicroseconds %
                        Duration.microsecondsPerMinute !=
                    0 ||
                s.preparationTime.inMinutes < 1 ||
                s.preparationTime.inMinutes > 1440,
          )) {
        _reject(ScheduleSaveFailure.invalid);
      }
    }
  }

  @override
  Future<ScheduleSaveReceipt> save(
    ScheduleFormSubmission v, {
    required bool editing,
  }) => db.transaction(() async {
    final baseline = v.baseline, mutation = v.mutationId;
    if (baseline == null || mutation == null || mutation.isEmpty) {
      _reject(ScheduleSaveFailure.invalid);
    }
    if (gate.isInvalidated || gate.isReplacingData || gate.isRecoveryPending) {
      _reject(ScheduleSaveFailure.unavailable);
    }
    final profile = await _profile();
    if (profile.storeIncarnation != baseline.store ||
        gate.generation != baseline.generation) {
      _reject(ScheduleSaveFailure.conflict);
    }
    _validate(v);
    if (!editing &&
        (v.schedule.isStarted ||
            v.schedule.startedAt != null ||
            v.schedule.finishedAt != null ||
            v.schedule.doneStatus != ScheduleDoneStatus.notEnded ||
            v.schedule.scoreContributionRecorded ||
            v.schedule.preparationFrozen ||
            v.schedule.recurringSlotKey != null ||
            v.schedule.recurringOrdinal != null ||
            v.schedule.recurringOverrides.isNotEmpty ||
            v.schedule.latenessTime != 0 ||
            v.schedule.recurringSegmentId != null ||
            v.schedule.preparationDefinitionId != null)) {
      _reject(ScheduleSaveFailure.invalid);
    }
    final digest = _digest(v, editing);
    final row = await (db.select(
      db.schedules,
    )..where((t) => t.id.equals(v.schedule.id))).getSingleOrNull();
    final recurringCreate = !editing && v.recurrenceRule != null;
    final following =
        editing &&
        baseline.rootId != null &&
        v.recurringScope == RecurringEditScope.following;
    final root = await _root(
      baseline.rootId ?? row?.recurringSegmentId,
      seriesId: recurringCreate ? v.schedule.id : null,
    );
    final rootReceipt = recurringCreate || following;
    if (rootReceipt &&
        root != null &&
        _receipt(
          root.lastMutationId,
          root.lastMutationDigest,
          root.aggregateVersion,
          root.lastMutationVersion,
          mutation,
          digest,
        )) {
      if (editing && root.aggregateIncarnation != baseline.rootIncarnation) {
        _reject(ScheduleSaveFailure.conflict);
      }
      return ScheduleSaveReceipt(
        scheduleId: v.schedule.id,
        mutationId: mutation,
        generation: gate.generation,
        changed: false,
      );
    }
    if (!rootReceipt &&
        row != null &&
        _receipt(
          row.lastMutationId,
          row.lastMutationDigest,
          row.aggregateVersion,
          row.lastMutationVersion,
          mutation,
          digest,
        )) {
      if (editing && row.aggregateIncarnation != baseline.incarnation) {
        _reject(ScheduleSaveFailure.conflict);
      }
      return ScheduleSaveReceipt(
        scheduleId: v.schedule.id,
        mutationId: mutation,
        generation: gate.generation,
        changed: false,
      );
    }
    if (v.validateTimeReview != null &&
        profile.dataRevision != baseline.revision) {
      _reject(ScheduleSaveFailure.conflict);
    }
    v.validateTimeReview?.call();
    if ((row?.lastMutationId == mutation &&
            row?.lastMutationDigest != digest) ||
        (root?.lastMutationId == mutation &&
            root?.lastMutationDigest != digest)) {
      _reject(ScheduleSaveFailure.conflict);
    }
    if (editing) {
      if (row == null ||
          row.aggregateIncarnation != baseline.incarnation ||
          row.aggregateVersion != baseline.version ||
          root?.aggregateIncarnation != baseline.rootIncarnation ||
          root?.aggregateVersion != baseline.rootVersion) {
        _reject(ScheduleSaveFailure.conflict);
      }
      final current = (await db.scheduleDao.getScheduleById(
        row.id,
      )).toScheduleEntity();
      final prep = await preparationFor(current);
      final lead =
          prep.totalDuration +
          current.moveTime +
          (current.scheduleSpareTime ?? Duration.zero);
      final currentInstant = ScheduleTimeResolver.resolve(
        current,
        nowUtc: now(),
      ).instantUtc;
      if (currentInstant == null ||
          current.isStarted ||
          current.preparationFrozen ||
          current.doneStatus != ScheduleDoneStatus.notEnded ||
          !currentInstant.subtract(lead).isAfter(now().toUtc())) {
        _reject(ScheduleSaveFailure.protected);
      }
    } else if (row != null ||
        root != null ||
        profile.dataRevision != baseline.revision) {
      _reject(ScheduleSaveFailure.conflict);
    }
    final priorOwnedDefinitions = <String>{
      if (row?.preparationDefinitionId != null) row!.preparationDefinitionId!,
    };
    if (following && root != null) {
      final parts = await (db.select(
        db.recurringScheduleSegments,
      )..where((t) => t.seriesId.equals(root.seriesId))).get();
      priorOwnedDefinitions.addAll(parts.map((p) => p.preparationId));
      final occurrences = await (db.select(
        db.schedules,
      )..where((t) => t.recurringSegmentId.isIn(parts.map((p) => p.id)))).get();
      priorOwnedDefinitions.addAll(
        occurrences.map((s) => s.preparationDefinitionId).whereType<String>(),
      );
    }
    var changed = true;
    if (recurringCreate) {
      await recurring.create(
        v.schedule,
        v.preparation,
        v.recurrenceRule!,
        excludedSlots: v.excludedSlots,
        reviewedFirstSlotKey: v.reviewedFirstSlotKey,
      );
    } else if (editing && row?.preparationDefinitionId != null) {
      final current = (await db.scheduleDao.getScheduleById(
        v.schedule.id,
      )).toScheduleEntity();
      final prep = await preparationFor(current);
      final same =
          jsonEncode(_editable(current, SchedulePreparationMode.custom)) ==
              jsonEncode(
                _editable(v.schedule, SchedulePreparationMode.custom),
              ) &&
          jsonEncode(_steps(prep)) == jsonEncode(_steps(v.preparation));
      if (same && (!following || await _sameFollowing(v, current))) {
        changed = false;
      } else if (following) {
        await recurring.updateFollowing(
          current,
          v.schedule,
          v.preparation,
          v.recurrenceRule!,
          countChanged: v.recurrenceCountChanged,
          excludedSlots: v.excludedSlots,
          reviewedFirstSlotKey: v.reviewedFirstSlotKey,
          confirmDetached: v.confirmDetached,
        );
      } else {
        await recurring.updateOccurrence(
          current,
          v.schedule,
          v.preparation,
          preparationChanged:
              jsonEncode(_steps(prep)) != jsonEncode(_steps(v.preparation)),
        );
      }
    } else {
      changed = await _saveOrdinary(v, editing: editing);
      if (changed) await db.userDao.markDurableDataChanged(localProfileId);
    }
    if (changed) {
      for (final candidate in priorOwnedDefinitions) {
        await _collectUnusedOwnedDefinition(candidate);
      }
    }
    // There are no OS/plugin awaits in this transaction. Recheck replacement
    // currentness immediately before returning its durable commit receipt.
    if (gate.generation != baseline.generation ||
        gate.isReplacingData ||
        gate.isInvalidated) {
      _reject(ScheduleSaveFailure.conflict);
    }
    if (rootReceipt) {
      final target = await _root(
        baseline.rootId,
        seriesId: recurringCreate ? v.schedule.id : null,
      );
      if (target == null) _reject(ScheduleSaveFailure.conflict);
      await (db.update(
        db.recurringScheduleSegments,
      )..where((t) => t.id.equals(target.id))).write(
        RecurringScheduleSegmentsCompanion(
          lastMutationId: Value(mutation),
          lastMutationDigest: Value(digest),
          lastMutationVersion: Value(target.aggregateVersion),
        ),
      );
    } else {
      final target = await (db.select(
        db.schedules,
      )..where((t) => t.id.equals(v.schedule.id))).getSingle();
      await (db.update(
        db.schedules,
      )..where((t) => t.id.equals(target.id))).write(
        SchedulesCompanion(
          lastMutationId: Value(mutation),
          lastMutationDigest: Value(digest),
          lastMutationVersion: Value(target.aggregateVersion),
        ),
      );
    }
    v.validateTimeReview?.call();
    return ScheduleSaveReceipt(
      scheduleId: v.schedule.id,
      mutationId: mutation,
      generation: gate.generation,
      changed: changed,
    );
  });

  Future<bool> _sameFollowing(
    ScheduleFormSubmission v,
    ScheduleEntity current,
  ) async {
    if (v.recurrenceCountChanged ||
        v.excludedSlots.isNotEmpty ||
        v.recurrenceRule == null) {
      return false;
    }
    final segment = await recurring.getSegment(current.recurringSegmentId!);
    final parts = await (db.select(
      db.recurringScheduleSegments,
    )..where((t) => t.seriesId.equals(segment.seriesId))).get();
    if (segment.beforeSlot != null ||
        parts.any(
          (p) =>
              p.id != segment.id &&
              _civilSlot(p.fromSlot).compareTo(segment.fromSlot) > 0,
        )) {
      return false;
    }
    final expected = segment.rule.withStartAndEnd(
      start: v.schedule.scheduleTime,
      count: segment.rule.count,
      until: segment.rule.until,
    );
    return jsonEncode(RecurrenceCodec.ruleToJson(expected)) ==
        jsonEncode(RecurrenceCodec.ruleToJson(v.recurrenceRule!));
  }

  Future<void> _collectUnusedOwnedDefinition(String candidate) =>
      collectUnusedScheduleDefinition(db, candidate);

  Future<bool> _saveOrdinary(
    ScheduleFormSubmission v, {
    required bool editing,
  }) async {
    final input = v.schedule, mode = _mode(v);
    PreparationEntity desired = v.preparation;
    if (mode == SchedulePreparationMode.template) {
      final template =
          await (db.select(db.preparationTemplates)
                ..where((t) => t.id.equals(input.preparationTemplateId!)))
              .getSingleOrNull();
      if (template == null) _reject(ScheduleSaveFailure.invalid);
      desired = (await db.preparationTemplateDao.getById(
        template.id,
      )).preparation;
    } else if (mode == SchedulePreparationMode.defaultPreparation) {
      desired = await db.preparationUserDao.getPreparationUsersByUserId(
        localProfileId,
      );
    }
    ScheduleEntity? current;
    PreparationEntity? previous;
    if (editing) {
      current = (await db.scheduleDao.getScheduleById(
        input.id,
      )).toScheduleEntity();
      previous = await preparationFor(current);
      final oldMode =
          current.preparationMode ??
          (current.isChanged
              ? SchedulePreparationMode.custom
              : SchedulePreparationMode.defaultPreparation);
      if (jsonEncode(_editable(current, oldMode)) ==
              jsonEncode(_editable(input, mode)) &&
          jsonEncode(_steps(previous)) == jsonEncode(_steps(desired))) {
        return false;
      }
    }
    final existingPlace = await (db.select(
      db.places,
    )..where((t) => t.id.equals(input.place.id))).getSingleOrNull();
    var place = input.place;
    if (existingPlace != null &&
        existingPlace.placeName != input.place.placeName) {
      place = PlaceEntity(id: uuid.v7(), placeName: input.place.placeName);
    }
    if (existingPlace == null || place.id != existingPlace.id) {
      await db.into(db.places).insert(place.toPlaceRow().toCompanion(false));
    }
    if (!editing) {
      final created = ScheduleEntity(
        id: input.id,
        place: place,
        scheduleName: input.scheduleName,
        scheduleTime: input.scheduleTime,
        timeZoneId: input.timeZoneId,
        occurrenceOffsetSeconds: input.occurrenceOffsetSeconds,
        moveTime: input.moveTime,
        scheduleSpareTime: input.scheduleSpareTime,
        scheduleNote: input.scheduleNote,
        isStarted: false,
        preparationTemplateId: input.preparationTemplateId,
        preparationTemplateName: input.preparationTemplateName,
        preparationMode: mode,
        isChanged: mode != SchedulePreparationMode.defaultPreparation,
      );
      await db
          .into(db.schedules)
          .insert(created.toScheduleRow().toCompanion(false));
    } else {
      await (db.update(
        db.schedules,
      )..where((t) => t.id.equals(input.id))).write(
        SchedulesCompanion(
          placeId: Value(place.id),
          scheduleName: Value(input.scheduleName),
          scheduleTime: Value(input.scheduleTime),
          timeZoneId: Value(input.timeZoneId),
          occurrenceOffsetSeconds: Value(input.occurrenceOffsetSeconds),
          moveTime: Value(input.moveTime),
          scheduleSpareTime: Value(input.scheduleSpareTime),
          scheduleNote: Value(input.scheduleNote),
          isChanged: Value(mode != SchedulePreparationMode.defaultPreparation),
          preparationMode: Value(mode.name),
          preparationTemplateId: Value(input.preparationTemplateId),
          preparationTemplateName: Value(input.preparationTemplateName),
          preparationTemplateDeleted: const Value(false),
        ),
      );
    }
    if (mode == SchedulePreparationMode.custom) {
      final own = await db.preparationScheduleDao
          .getPreparationSchedulesByScheduleId(input.id);
      final old = own.ordered.preparationStepList;
      final steps = desired.ordered.preparationStepList;
      // Existing owned IDs survive semantic edits; a copied template/default
      // never takes ownership of the source's IDs.
      final ids = [
        for (var i = 0; i < steps.length; i++)
          i < old.length ? old[i].id : uuid.v7(),
      ];
      await db.preparationScheduleDao.createPreparationSchedule(
        PreparationEntity(
          preparationStepList: [
            for (var i = 0; i < steps.length; i++)
              PreparationStepEntity(
                id: ids[i],
                preparationName: steps[i].preparationName,
                preparationTime: steps[i].preparationTime,
                nextPreparationId: i + 1 < ids.length ? ids[i + 1] : null,
              ),
          ],
        ),
        input.id,
      );
    } else {
      await (db.delete(
        db.preparationSchedules,
      )..where((t) => t.scheduleId.equals(input.id))).go();
    }
    return true;
  }
}

Future<PreparationEntity> readSchedulePreparation(
  AppDatabase db,
  ScheduleEntity schedule,
) async {
  if (schedule.preparationMode == SchedulePreparationMode.template &&
      schedule.preparationTemplateId != null &&
      !schedule.preparationTemplateDeleted) {
    final exists =
        await (db.select(db.preparationTemplates)
              ..where((t) => t.id.equals(schedule.preparationTemplateId!)))
            .getSingleOrNull();
    if (exists != null) {
      return (await db.preparationTemplateDao.getById(exists.id)).preparation;
    }
  }
  final custom = await PreparationLocalDataSourceImpl(
    appDatabase: db,
  ).getPreparationByScheduleId(schedule.id);
  if (custom.preparationStepList.isNotEmpty) return custom;
  return db.preparationUserDao.getPreparationUsersByUserId(localProfileId);
}

DateTime _civilSlot(String value) => CivilDateTime.parse(value).toUtcCarrier();
