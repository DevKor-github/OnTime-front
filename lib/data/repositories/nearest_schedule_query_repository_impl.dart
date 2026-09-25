import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/schedule_aggregate_repository_impl.dart';
import 'package:on_time_front/domain/entities/nearest_schedule_query.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/repositories/nearest_schedule_query_repository.dart';
import 'package:on_time_front/domain/repositories/recurring_schedule_repository.dart';

@Singleton(as: NearestScheduleQueryRepository)
class NearestScheduleQueryRepositoryImpl
    implements NearestScheduleQueryRepository {
  NearestScheduleQueryRepositoryImpl(
    this.db,
    this.recurring, {
    @ignoreParam DateTime Function()? now,
    @ignoreParam LocalDataOperationGate? gate,
    @ignoreParam this.totalBudget = 200000,
  }) : now = now ?? DateTime.now,
       gate = gate ?? LocalDataOperationGate.shared;
  final AppDatabase db;
  final RecurringScheduleRepository recurring;
  final DateTime Function() now;
  final LocalDataOperationGate gate;
  final int totalBudget;

  @override
  Stream<void> get changes => db.scheduleDao.watchScheduleList().map((_) {});

  Future<String> _signature() async {
    final parts = <Object>[];
    for (final tableName in [
      db.users.actualTableName,
      db.schedules.actualTableName,
      db.places.actualTableName,
      db.preparationSchedules.actualTableName,
      db.preparationUsers.actualTableName,
      db.preparationTemplates.actualTableName,
      db.preparationTemplateSteps.actualTableName,
      db.preparationDefinitions.actualTableName,
      db.preparationDefinitionSteps.actualTableName,
      db.recurringScheduleSegments.actualTableName,
      db.recurringScheduleExclusions.actualTableName,
    ]) {
      final rows = await db.customSelect('SELECT * FROM $tableName').get();
      final encoded = rows.map((row) => jsonEncode(row.data)).toList()..sort();
      parts.add(encoded);
    }
    return sha256.convert(utf8.encode(jsonEncode(parts))).toString();
  }

  Future<User> _profile() => (db.select(
    db.users,
  )..where((t) => t.id.equals(localProfileId))).getSingle();

  @override
  Future<NearestScheduleQuerySession> open(NearestQueryKey key) async {
    final evaluated = now().toUtc();
    final rules = TimeZoneRules.loadedIdentity;
    return db.transaction(() async {
      gate.checkWrite(key.generation);
      final profile = await _profile();
      final stored = (await db.scheduleDao.getScheduleList())
          .map((v) => v.toScheduleEntity())
          .toList();
      final segments = await recurring.getSegments();
      final exclusions = await db.select(db.recurringScheduleExclusions).get();
      final signature = await _signature();
      gate.checkWrite(key.generation);
      return _Session(
        this,
        key,
        evaluated,
        rules,
        profile.storeIncarnation!,
        profile.dataRevision,
        signature,
        stored,
        segments,
        {
          for (final segment in segments)
            segment.id: exclusions
                .where((v) => v.segmentId == segment.id)
                .map((v) => v.slotKey)
                .toSet(),
        },
      );
    });
  }

  Future<ScheduleWithPreparationEntity> _readPreparation(
    ScheduleEntity selected,
    DateTime evaluated,
  ) async {
    final raw = await (db.select(
      db.schedules,
    )..where((t) => t.id.equals(selected.id))).getSingleOrNull();
    if (raw == null) throw const NearestQueryInvalidated();
    final actual = (await db.scheduleDao.getScheduleById(
      selected.id,
    )).toScheduleEntity();
    if (actual.preparationDefinitionId != null) {
      final exists =
          await (db.select(db.preparationDefinitions)
                ..where((t) => t.id.equals(actual.preparationDefinitionId!)))
              .getSingleOrNull();
      if (exists == null) throw const _MissingPreparation();
    }
    final preparation = await readSchedulePreparation(db, actual);
    return ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
      actual,
      PreparationWithTimeEntity.fromPreparation(preparation),
      timeResolution: ScheduleTimeResolver.resolve(actual, nowUtc: evaluated),
    );
  }

  @override
  Future<ScheduleWithPreparationEntity?> readActive() => db.transaction(
    () async {
      final generation = gate.generation;
      gate.checkWrite(generation);
      final rows = (await db.scheduleDao.getScheduleList())
          .map((v) => v.toScheduleEntity())
          .where(_active)
          .toList();
      final evaluated = now().toUtc();
      for (final row in rows) {
        final resolution = ScheduleTimeResolver.resolve(row, nowUtc: evaluated);
        if (resolution.instantUtc == null) {
          throw ScheduleTimeUnresolved(resolution.status);
        }
      }
      rows.sort((a, b) {
        final comparison = a.startedAt!.compareTo(b.startedAt!);
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });
      final result = rows.isEmpty
          ? null
          : await _readPreparation(rows.first, evaluated);
      gate.checkWrite(generation);
      return result;
    },
  );
}

bool _active(ScheduleEntity s) =>
    s.isStarted &&
    s.startedAt != null &&
    s.preparationFrozen &&
    s.doneStatus == ScheduleDoneStatus.notEnded;

final class _MissingPreparation implements Exception {
  const _MissingPreparation();
}

final class _Probe {
  _Probe(this.segment, this.iterator, this.maximumOffset);
  final RecurringSegment segment;
  final Iterator<RecurrenceScanStep> iterator;
  final Duration maximumOffset;
  DateTime? frontier;
  bool complete = false;
  bool outOfRange = false;
  bool proves(DateTime? target) =>
      complete ||
      (target != null &&
          frontier != null &&
          frontier!.subtract(maximumOffset).isAfter(target));
}

final class _Session implements NearestScheduleQuerySession {
  _Session(
    this.repository,
    this.key,
    this.evaluated,
    this.rules,
    this.store,
    this.revision,
    this.signature,
    List<ScheduleEntity> stored,
    List<RecurringSegment> segments,
    Map<String, Set<String>> exclusions,
  ) {
    candidates.addAll(stored);
    final ownedSlots = {
      for (final row in stored)
        if (row.recurringSegmentId != null && row.recurringSlotKey != null)
          '${row.recurringSegmentId}:${row.recurringSlotKey}',
    };
    for (final segment in segments) {
      if (!TimeZoneRules.contains(segment.rule.timeZoneId)) {
        issues.add(
          NearestQueryIssue(
            reason: NearestQueryIssueReason.unknownTimeZone,
            segmentId: segment.id,
          ),
        );
        continue;
      }
      final zones = TimeZoneRules.location(segment.rule.timeZoneId).zones;
      final maxOffset = zones
          .map((z) => z.offset)
          .fold<int>(-86400000, (a, b) => a > b ? a : b);
      final excluded = {
        ...?exclusions[segment.id],
        for (final row in stored)
          if (row.recurringSegmentId == segment.id &&
              row.recurringSlotKey != null &&
              ownedSlots.contains('${segment.id}:${row.recurringSlotKey}'))
            row.recurringSlotKey!,
      };
      probes.add(
        _Probe(
          segment,
          const RecurrenceEngine()
              .scan(
                segment.rule,
                through: segment.beforeSlot ?? DateTime.utc(9999, 12, 31),
                from: segment.fromSlot,
                preparationNotBeforeUtc: segment.preparationNotBefore,
                leadTime: segment.leadTime,
                excludedKeys: excluded,
              )
              .iterator,
          Duration(milliseconds: maxOffset),
        ),
      );
    }
  }
  final NearestScheduleQueryRepositoryImpl repository;
  final NearestQueryKey key;
  final DateTime evaluated;
  DateTime? publicationFloor;
  final String rules;
  final String store;
  int revision;
  String signature;
  final candidates = <ScheduleEntity>[];
  final generated = <String, (_Probe, RecurrenceSlot)>{};
  final probes = <_Probe>[];
  final issues = <NearestQueryIssue>[];
  int visited = 0;
  int nextProbe = 0;
  bool cancelled = false;
  @override
  void cancel() {
    cancelled = true;
    candidates.clear();
    generated.clear();
    probes.clear();
  }

  void check() {
    if (cancelled ||
        key.generation != repository.gate.generation ||
        !repository.gate.isAvailable) {
      throw const NearestQueryInvalidated();
    }
  }

  List<(ScheduleEntity, ScheduleTimeResolution)> eligible(DateTime now) {
    final found = <(ScheduleEntity, ScheduleTimeResolution)>[];
    for (final row in candidates) {
      if (row.doneStatus != ScheduleDoneStatus.notEnded ||
          row.retainedRecurringReference ||
          _active(row)) {
        continue;
      }
      final resolved = ScheduleTimeResolver.resolve(row, nowUtc: now);
      if (resolved.instantUtc == null) {
        if (resolved.isHistorical) continue;
        final reason = switch (resolved.status) {
          ScheduleTimeResolutionStatus.unknownZone =>
            NearestQueryIssueReason.unknownTimeZone,
          ScheduleTimeResolutionStatus.ambiguous =>
            NearestQueryIssueReason.ambiguousOccurrence,
          ScheduleTimeResolutionStatus.nonexistent =>
            NearestQueryIssueReason.nonexistentCivilTime,
          ScheduleTimeResolutionStatus.changed =>
            NearestQueryIssueReason.changedTimeRules,
          ScheduleTimeResolutionStatus.historicalUncertain =>
            NearestQueryIssueReason.uncertainHistoricalTime,
          _ => NearestQueryIssueReason.invalidTimeMetadata,
        };
        final issue = NearestQueryIssue(reason: reason, scheduleId: row.id);
        if (!issues.contains(issue)) issues.add(issue);
        continue;
      }
      if (!resolved.instantUtc!.isBefore(now)) found.add((row, resolved));
    }
    found.sort((a, b) {
      final time = a.$2.instantUtc!.compareTo(b.$2.instantUtc!);
      return time != 0 ? time : a.$1.id.compareTo(b.$1.id);
    });
    return found;
  }

  NearestQueryProgress progress(DateTime? target) => NearestQueryProgress(
    visitedCandidates: visited,
    candidateBudget: repository.totalBudget,
    provenSegments: probes.where((p) => p.proves(target)).length,
    totalSegments: probes.length,
  );
  @override
  Future<NearestScheduleQuery> advance({required int candidateBudget}) async {
    check();
    var found = eligible(publicationFloor ?? evaluated);
    DateTime? target = found.isEmpty ? null : found.first.$2.instantUtc;
    var remaining = candidateBudget;
    while (remaining > 0 &&
        visited < repository.totalBudget &&
        probes.any((p) => !p.proves(target) && !p.outOfRange)) {
      final probe = probes[nextProbe++ % probes.length];
      if (probe.proves(target) || probe.outOfRange) continue;
      remaining--;
      visited++;
      try {
        if (!probe.iterator.moveNext()) {
          probe.complete =
              probe.segment.beforeSlot != null ||
              probe.segment.rule.until != null;
          probe.outOfRange = !probe.complete;
          continue;
        }
        final step = probe.iterator.current;
        probe.frontier = step.frontierCivil;
        if (probe.segment.beforeSlot != null &&
            !step.frontierCivil.isBefore(probe.segment.beforeSlot!)) {
          probe.complete = true;
          continue;
        }
        if (step.countComplete) probe.complete = true;
        final slot = step.slot;
        if (slot != null &&
            probe.segment.includes(slot) &&
            !slot.instantUtc.isBefore(evaluated)) {
          final value = repository.recurring.candidateFor(probe.segment, slot);
          candidates.add(value);
          generated[value.id] = (probe, slot);
          found = eligible(publicationFloor ?? evaluated);
          target = found.isEmpty ? null : found.first.$2.instantUtc;
        }
      } on RepeatedTimeChoiceRequired {
        issues.add(
          NearestQueryIssue(
            reason: NearestQueryIssueReason.ambiguousOccurrence,
            segmentId: probe.segment.id,
          ),
        );
        probe.complete = true;
      }
    }
    check();
    found = eligible(publicationFloor ?? evaluated);
    target = found.isEmpty ? null : found.first.$2.instantUtc;
    final currentProgress = progress(target);
    if (probes.any((p) => !p.proves(target))) {
      final exhausted = visited >= repository.totalBudget;
      final range = probes.any((p) => p.outOfRange && !p.proves(target));
      return NearestQueryLimited(
        key: key,
        reason: exhausted
            ? NearestQueryLimitReason.searchBudgetExhausted
            : range
            ? NearestQueryLimitReason.representableRangeExhausted
            : NearestQueryLimitReason.interrupted,
        progress: currentProgress,
        canContinue: !exhausted && !range,
        canRetry: false,
        issues: List.unmodifiable(issues),
      );
    }
    if (TimeZoneRules.loadedIdentity != rules) {
      throw const NearestQueryInvalidated();
    }
    try {
      return await repository.db.writeTransaction(() async {
        check();
        if (await repository._signature() != signature) {
          throw const NearestQueryInvalidated();
        }
        check();
        final now = repository.now().toUtc();
        found = eligible(now);
        target = found.isEmpty ? null : found.first.$2.instantUtc;
        if (probes.any((p) => !p.proves(target))) {
          publicationFloor = now;
          return NearestQueryLimited(
            key: key,
            reason: NearestQueryLimitReason.interrupted,
            progress: progress(target),
            canContinue: true,
            canRetry: false,
            issues: List.unmodifiable(issues),
          );
        }
        if (found.isEmpty && issues.isNotEmpty) {
          return NearestQueryError(
            key: key,
            reason: NearestQueryFailureReason.recurrenceMetadataInvalid,
            issues: List.unmodifiable(issues),
          );
        }
        ScheduleWithPreparationEntity? selected;
        if (found.isNotEmpty) {
          var value = found.first.$1;
          final created = generated[value.id];
          if (created != null) {
            value = await repository.recurring.materializeCandidate(
              created.$1.segment,
              created.$2,
            );
          }
          try {
            selected = await repository._readPreparation(value, now);
          } on _MissingPreparation {
            throw const _PreparationReadFailure(
              NearestQueryFailureReason.preparationMissing,
            );
          } on NearestQueryInvalidated {
            rethrow;
          } catch (_) {
            throw const _PreparationReadFailure(
              NearestQueryFailureReason.preparationReadFailed,
            );
          }
        }
        check();
        if (TimeZoneRules.loadedIdentity != rules) {
          throw const NearestQueryInvalidated();
        }
        final profile = await repository._profile();
        revision = profile.dataRevision;
        signature = await repository._signature();
        final verifiedNow = repository.now().toUtc();
        if (selected != null &&
            (selected.timeResolution?.instantUtc == null ||
                selected.timeResolution!.instantUtc!.isBefore(verifiedNow))) {
          throw const NearestQueryInvalidated();
        }
        final authority = NearestQueryAuthority(
          key: key,
          storeIncarnation: store,
          dataRevision: revision,
          ruleDataIdentity: rules,
          evaluatedAtUtc: evaluated,
          verifiedAtUtc: repository.now().toUtc(),
        );
        return selected == null
            ? NearestQueryEmpty(authority: authority, issues: issues)
            : NearestQueryReady(
                value: NearestVerifiedSchedule(
                  schedule: selected,
                  resolution: selected.timeResolution!,
                  authority: authority,
                ),
                issues: issues,
              );
      }, gate: repository.gate);
    } on _PreparationReadFailure catch (failure) {
      return NearestQueryError(
        key: key,
        reason: failure.reason,
        issues: List.unmodifiable(issues),
      );
    }
  }
}

final class _PreparationReadFailure implements Exception {
  const _PreparationReadFailure(this.reason);
  final NearestQueryFailureReason reason;
}
