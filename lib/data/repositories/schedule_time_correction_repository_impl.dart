import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/time/time_correction_conflicts.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'time_correction_conflict_reader.dart';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/schedule_time_correction.dart';
import 'package:on_time_front/domain/recurrence/recurrence_reference_policy.dart';
import 'package:on_time_front/domain/repositories/schedule_aggregate_repository.dart';
import 'package:on_time_front/domain/repositories/schedule_time_correction_repository.dart';

@Singleton(as: ScheduleTimeCorrectionRepository)
class ScheduleTimeCorrectionRepositoryImpl
    implements ScheduleTimeCorrectionRepository {
  ScheduleTimeCorrectionRepositoryImpl(
    this.db,
    this.aggregates, {
    @ignoreParam LocalDataOperationGate? gate,
    @ignoreParam DateTime Function()? now,
  }) : gate = gate ?? LocalDataOperationGate.shared,
       now = now ?? DateTime.now;

  final AppDatabase db;
  final ScheduleAggregateRepository aggregates;
  final LocalDataOperationGate gate;
  final DateTime Function() now;

  Never _reject(ScheduleSaveFailure failure) =>
      throw ScheduleSaveRejected(failure);

  void _available() {
    if (gate.isInvalidated || gate.isReplacingData || gate.isRecoveryPending) {
      _reject(ScheduleSaveFailure.unavailable);
    }
  }

  @override
  bool isCurrent(ScheduleSaveReceipt receipt) =>
      !gate.isInvalidated &&
      !gate.isReplacingData &&
      !gate.isRecoveryPending &&
      receipt.generation == gate.generation;

  void _repairable(
    ScheduleEntity schedule,
    ScheduleTimeResolution resolution,
    DateTime at,
  ) {
    if (RecurrenceReferencePolicy.hasProtectedFacts(schedule) ||
        resolution.isHistorical ||
        schedule.startedAt != null ||
        schedule.finishedAt != null ||
        schedule.scoreContributionRecorded ||
        schedule.retainedRecurringReference ||
        RecurrenceReferencePolicy.isProvablyPast(schedule, at)) {
      _reject(ScheduleSaveFailure.protected);
    }
    switch (resolution.status) {
      case ScheduleTimeResolutionStatus.unknownZone:
      case ScheduleTimeResolutionStatus.nonexistent:
      case ScheduleTimeResolutionStatus.ambiguous:
      case ScheduleTimeResolutionStatus.changed:
        break;
      case ScheduleTimeResolutionStatus.resolved:
      case ScheduleTimeResolutionStatus.historicalUncertain:
      case ScheduleTimeResolutionStatus.invalid:
        _reject(ScheduleSaveFailure.protected);
    }
  }

  @override
  Future<ScheduleTimeCorrectionReview> review(String scheduleId) =>
      db.transaction(() async {
        _available();
        final identity = TimeZoneRules.loadedIdentity;
        final at = now().toUtc();
        final snapshot = await aggregates.readForEdit(scheduleId);
        final resolution = ScheduleTimeResolver.resolve(
          snapshot.schedule,
          nowUtc: at,
        );
        ScheduleSaveFailure? blockedBy;
        try {
          _repairable(snapshot.schedule, resolution, at);
        } on ScheduleSaveRejected catch (failure) {
          blockedBy = failure.failure;
        }
        _available();
        if (snapshot.baseline.generation != gate.generation ||
            identity != TimeZoneRules.loadedIdentity) {
          _reject(ScheduleSaveFailure.conflict);
        }
        return ScheduleTimeCorrectionReview(
          snapshot: snapshot,
          resolution: resolution,
          ruleIdentity: identity,
          validationNowUtc: at,
          blockedBy: blockedBy,
        );
      });

  @override
  Future<TimeCorrectionConflictProof> reviewChoice(
    ScheduleTimeCorrectionCommand command,
  ) => db.transaction(() async {
    _available();
    final at = now().toUtc();
    final snapshot = await aggregates.readForEdit(
      command.review.snapshot.schedule.id,
    );
    if (snapshot.baseline != command.review.snapshot.baseline) {
      _reject(ScheduleSaveFailure.conflict);
    }
    final current = ScheduleTimeResolver.resolve(snapshot.schedule, nowUtc: at);
    _validateAuthority(command, current, at, TimeZoneRules.loadedIdentity);
    _repairable(snapshot.schedule, current, at);
    final desired = snapshot.schedule.copyWith(
      scheduleTime: command.civil.toUtcCarrier(),
      timeZoneId: command.timeZoneId,
      occurrenceOffsetSeconds: command.offsetSeconds,
    );
    final time = ScheduleTimeResolver.resolve(desired, nowUtc: at);
    final instant = time.instantUtc;
    final lead =
        snapshot.preparation.totalDuration +
        desired.moveTime +
        (desired.scheduleSpareTime ?? Duration.zero);
    if (time.status != ScheduleTimeResolutionStatus.resolved ||
        time.isHistorical ||
        instant == null ||
        !instant.subtract(lead).isAfter(at)) {
      _reject(ScheduleSaveFailure.invalid);
    }
    final budget = BackupBudget();
    final world = await readTimeCorrectionConflictWorld(
      db: db,
      nowUtc: at,
      budget: budget,
      ignoredIds: {desired.id},
    );
    final offsets = time.occurrences;
    final rule = RecurrenceRule(
      frequency: RecurrenceFrequency.daily,
      start: command.civil.toUtcCarrier(),
      timeZoneId: command.timeZoneId,
      count: 1,
      repeatedTime: offsets.length > 1
          ? offsets.first.offsetSeconds == command.offsetSeconds
                ? RepeatedCivilTime.first
                : RepeatedCivilTime.second
          : null,
    );
    final proof = await TimeCorrectionConflictScanner.scan(
      rule: rule,
      base: desired,
      basePreparation: snapshot.preparation.totalDuration,
      proposedOverrides: {rule.start.toIso8601String(): desired},
      proposedPreparationById: {desired.id: snapshot.preparation.totalDuration},
      excludedSlots: {},
      storedOthers: world.rows,
      otherSegments: world.segments,
      otherExcludedSlots: world.exclusions,
      nowUtc: at,
      budget: budget,
    );
    final finalNow = now().toUtc();
    if (finalNow.isBefore(at) || !instant.subtract(lead).isAfter(finalNow)) {
      _reject(ScheduleSaveFailure.conflict);
    }
    _validateAuthority(
      command,
      ScheduleTimeResolver.resolve(snapshot.schedule, nowUtc: finalNow),
      finalNow,
      TimeZoneRules.loadedIdentity,
    );
    _available();
    return TimeCorrectionConflictProof(
      conflicts: proof.conflicts,
      through: proof.through,
      workUnits: budget.work,
      possibleOverlaps: [
        ...world.possibleOverlaps,
        ...proof.possibleOverlaps,
      ].where((e) => e.mayOverlap(instant.subtract(lead), instant)).toList(),
    );
  });

  String _digest(ScheduleTimeCorrectionCommand command) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            'time-correction-v1',
            command.review.snapshot.schedule.id,
            command.review.snapshot.baseline.props,
            command.review.ruleIdentity,
            command.review.validationNowUtc.toUtc().toIso8601String(),
            command.civil.toCivilIso8601String(),
            command.timeZoneId,
            command.offsetSeconds,
            command.acknowledgedUncertainIds.toList()..sort(),
          ]),
        ),
      )
      .toString();

  @override
  Future<ScheduleSaveReceipt> confirm(ScheduleTimeCorrectionCommand command) =>
      db.transaction(() async {
        _available();
        final expected = command.review.snapshot.baseline;
        final id = command.review.snapshot.schedule.id;
        if (command.mutationId.isEmpty ||
            expected.incarnation == null ||
            expected.version == null) {
          _reject(ScheduleSaveFailure.invalid);
        }
        final profile = await (db.select(
          db.users,
        )..where((t) => t.id.equals(localProfileId))).getSingle();
        if (profile.storeIncarnation != expected.store ||
            gate.generation != expected.generation) {
          _reject(ScheduleSaveFailure.conflict);
        }
        final row = await (db.select(
          db.schedules,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (row == null || row.aggregateIncarnation != expected.incarnation) {
          _reject(ScheduleSaveFailure.conflict);
        }
        final digest = _digest(command);
        // A retry acknowledges the original commit; it does not reinterpret or
        // write again if time/rules have moved since that successful command.
        if (row.lastMutationId == command.mutationId &&
            row.lastMutationDigest == digest &&
            row.lastMutationVersion == row.aggregateVersion) {
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
        final current = await aggregates.readForEdit(id);
        if (current.baseline != expected) {
          _reject(ScheduleSaveFailure.conflict);
        }
        final evaluationNow = now().toUtc();
        final rules = TimeZoneRules.loadedIdentity;
        final original = ScheduleTimeResolver.resolve(
          current.schedule,
          nowUtc: evaluationNow,
        );
        _validateAuthority(command, original, evaluationNow, rules);
        _repairable(current.schedule, original, evaluationNow);
        final desired = current.schedule.copyWith(
          scheduleTime: command.civil.toUtcCarrier(),
          timeZoneId: command.timeZoneId,
          occurrenceOffsetSeconds: command.offsetSeconds,
        );
        final lead =
            current.preparation.totalDuration +
            current.schedule.moveTime +
            (current.schedule.scheduleSpareTime ?? Duration.zero);
        void validateChoice(DateTime at) {
          final result = ScheduleTimeResolver.resolve(desired, nowUtc: at);
          final instant = result.instantUtc;
          if (result.status != ScheduleTimeResolutionStatus.resolved ||
              result.isHistorical ||
              instant == null ||
              !instant.isAfter(at) ||
              !instant.subtract(lead).isAfter(at)) {
            _reject(ScheduleSaveFailure.invalid);
          }
        }

        validateChoice(evaluationNow);
        final proof = await reviewChoice(command);
        if (proof.conflicts.isNotEmpty) {
          throw ScheduleTimeCorrectionConflict(proof);
        }
        if (!const SetEquality<String>().equals(
          command.acknowledgedUncertainIds,
          proof.possibleOverlaps.map((e) => e.id).toSet(),
        )) {
          _reject(ScheduleSaveFailure.invalid);
        }
        final overrides = current.schedule.recurringOverrides
            .split(',')
            .where((value) => value.isNotEmpty)
            .toSet();
        if (current.schedule.isRecurring) overrides.add('time');
        await (db.update(db.schedules)..where((t) => t.id.equals(id))).write(
          SchedulesCompanion(
            scheduleTime: Value(command.civil.toUtcCarrier()),
            timeZoneId: Value(command.timeZoneId),
            occurrenceOffsetSeconds: Value(command.offsetSeconds),
            recurringOverrides: Value((overrides.toList()..sort()).join(',')),
          ),
        );
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
        // No OS side effect occurs in this transaction. If an awaited write
        // crosses a meaningful boundary, every write above is rolled back.
        final finalNow = now().toUtc();
        if (finalNow.isBefore(evaluationNow)) {
          _reject(ScheduleSaveFailure.conflict);
        }
        _validateAuthority(
          command,
          ScheduleTimeResolver.resolve(current.schedule, nowUtc: finalNow),
          finalNow,
          TimeZoneRules.loadedIdentity,
        );
        _repairable(current.schedule, original, finalNow);
        validateChoice(finalNow);
        _available();
        if (gate.generation != expected.generation) {
          _reject(ScheduleSaveFailure.conflict);
        }
        return ScheduleSaveReceipt(
          scheduleId: id,
          mutationId: command.mutationId,
          generation: gate.generation,
          changed: true,
        );
      });

  void _validateAuthority(
    ScheduleTimeCorrectionCommand command,
    ScheduleTimeResolution actual,
    DateTime at,
    String ruleIdentity,
  ) {
    if (at.isBefore(command.review.validationNowUtc.toUtc()) ||
        ruleIdentity != command.review.ruleIdentity ||
        actual != command.review.resolution) {
      _reject(ScheduleSaveFailure.conflict);
    }
  }
}
