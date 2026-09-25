import 'package:on_time_front/data/daos/schedule_owned_content_cleanup.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/recurrence/recurrence_reference_policy.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/schedule_save.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/core/time/civil_time_resolver.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/mappers/recurrence_codec.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/recurrence/recurrence_engine.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';
import 'package:on_time_front/domain/recurrence/recurring_schedule.dart';
import 'package:on_time_front/domain/repositories/recurring_schedule_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;

@Singleton(as: RecurringScheduleRepository)
class RecurringScheduleRepositoryImpl implements RecurringScheduleRepository {
  RecurringScheduleRepositoryImpl(
    this.db, {
    @ignoreParam DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _now;
  static const _engine = RecurrenceEngine();
  static const _uuid = Uuid();

  @override
  Future<List<RecurringSegment>> getSegments() async {
    final rows = await db.select(db.recurringScheduleSegments).get();
    return Future.wait(rows.map(_segment));
  }

  @override
  Future<RecurringSegment> getSegment(String id) async => _segment(
    await (db.select(
      db.recurringScheduleSegments,
    )..where((t) => t.id.equals(id))).getSingle(),
  );
  Future<RecurringSegment> _segment(RecurringScheduleSegment r) async =>
      RecurringSegment(
        id: r.id,
        seriesId: r.seriesId,
        rule: RecurrenceCodec.ruleFromJson(jsonDecode(r.ruleJson)),
        schedule: RecurrenceCodec.scheduleFromJson(jsonDecode(r.scheduleJson)),
        preparation: await getPreparation(r.preparationId),
        preparationId: r.preparationId,
        fromSlot: _civilSlot(r.fromSlot),
        beforeSlot: r.beforeSlot == null ? null : _civilSlot(r.beforeSlot!),
        createdAt: r.createdAt,
        preparationNotBefore: r.preparationNotBefore,
      );

  @override
  Future<PreparationEntity> getPreparation(String definitionId) async {
    final rows =
        await (db.select(db.preparationDefinitionSteps)
              ..where((t) => t.definitionId.equals(definitionId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    return PreparationEntity(
      preparationStepList: [
        for (var i = 0; i < rows.length; i++)
          PreparationStepEntity(
            id: rows[i].id,
            preparationName: rows[i].name,
            preparationTime: Duration(minutes: rows[i].minutes),
            nextPreparationId: i + 1 < rows.length ? rows[i + 1].id : null,
          ),
      ],
    );
  }

  Future<String> _savePreparation(
    PreparationEntity preparation,
    String owner,
    String name, {
    String scope = 'recurring',
  }) async {
    _validatePreparation(preparation);
    final id = _uuid.v7();
    await db
        .into(db.preparationDefinitions)
        .insert(
          PreparationDefinitionsCompanion.insert(
            id: id,
            ownerId: owner,
            scope: scope,
            name: name,
            createdAt: _now(),
          ),
        );
    for (final (i, step) in preparation.ordered.preparationStepList.indexed) {
      await db
          .into(db.preparationDefinitionSteps)
          .insert(
            PreparationDefinitionStepsCompanion.insert(
              id: _uuid.v7(),
              definitionId: id,
              name: step.preparationName,
              minutes: step.preparationTime.inMinutes,
              position: i,
            ),
          );
    }
    return id;
  }

  void _validatePreparation(PreparationEntity p) {
    if (p.preparationStepList.isEmpty ||
        p.preparationStepList.any(
          (s) =>
              s.preparationName.trim().isEmpty ||
              s.preparationName.length > 30 ||
              s.preparationTime.isNegative ||
              s.preparationTime.inMinutes > 1440,
        )) {
      throw const RecurrenceValidationException('준비 단계와 시간을 확인해 주세요.');
    }
  }

  Duration _lead(ScheduleEntity s, PreparationEntity p) =>
      p.totalDuration + s.moveTime + (s.scheduleSpareTime ?? Duration.zero);
  String _day(DateTime d) => RecurrenceRule.civilDate(d).toIso8601String();
  bool _protected(ScheduleEntity s) =>
      s.isStarted ||
      s.preparationFrozen ||
      s.doneStatus != ScheduleDoneStatus.notEnded ||
      (ScheduleTimeResolver.resolve(
            s,
            nowUtc: _now(),
          ).instantUtc?.isBefore(_now().toUtc()) ??
          true);
  Future<Set<String>> _excluded(String id) async => (await (db.select(
    db.recurringScheduleExclusions,
  )..where((t) => t.segmentId.equals(id))).get()).map((e) => e.slotKey).toSet();
  List<RecurrenceSlot> _expandSegment(
    RecurringSegment s,
    DateTime through, {
    DateTime? from,
    int? limit,
    Set<String> excluded = const {},
  }) {
    var lower = from == null ? s.fromSlot : RecurrenceRule.civilTime(from);
    if (lower.isBefore(s.fromSlot)) lower = s.fromSlot;
    var upper = RecurrenceRule.civilTime(through);
    if (s.beforeSlot != null && s.beforeSlot!.isBefore(upper)) {
      upper = s.beforeSlot!;
    }
    if (s.beforeSlot != null && !lower.isBefore(s.beforeSlot!)) return [];
    return _engine
        .expand(
          s.rule,
          through: upper,
          from: lower,
          limit: limit,
          leadTime: s.leadTime,
          preparationNotBeforeUtc: s.preparationNotBefore,
          excludedKeys: excluded,
        )
        .slots
        .where(s.includes)
        .toList();
  }

  ScheduleEntity _occurrence(RecurringSegment s, RecurrenceSlot slot) =>
      s.schedule.copyWith(
        id: _uuid.v5(
          Namespace.url.value,
          'ontime:${s.seriesId}:${s.id}:${_day(slot.civilTime)}',
        ),
        scheduleTime: slot.civilTime,
        timeZoneId: s.rule.timeZoneId,
        occurrenceOffsetSeconds: slot.offsetSeconds,
        recurringSegmentId: s.id,
        recurringSlotKey: slot.key,
        recurringOrdinal: slot.ordinal,
        preparationDefinitionId: s.preparationId,
        recurringOverrides: '',
        preparationMode: SchedulePreparationMode.custom,
        isChanged: true,
        isStarted: false,
      );

  @override
  ScheduleEntity candidateFor(RecurringSegment segment, RecurrenceSlot slot) =>
      _occurrence(segment, slot);

  @override
  Future<ScheduleEntity> materializeCandidate(
    RecurringSegment segment,
    RecurrenceSlot slot,
  ) async {
    if (!segment.includes(slot) ||
        (await _excluded(segment.id)).contains(slot.key)) {
      throw const RecurrenceSearchLimit();
    }
    final candidate = _occurrence(segment, slot);
    final existing =
        await (db.select(db.schedules)..where(
              (row) =>
                  row.id.equals(candidate.id) |
                  (row.recurringSegmentId.equals(segment.id) &
                      row.recurringSlotKey.equals(slot.key)),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await db.scheduleDao.createSchedule(candidate.toScheduleWithPlaceRow());
    }
    return (await db.scheduleDao.getScheduleById(
      existing?.id ?? candidate.id,
    )).toScheduleEntity();
  }

  // The Gregorian weekday/month calendar repeats after 146097 days. Combine
  // that cycle with both interval periods; never claim a partial scan proves an
  // unbounded rule is conflict-free. Oversized scans fail explicitly.
  int _period(RecurrenceRule r) => switch (r.frequency) {
    RecurrenceFrequency.daily => r.interval,
    RecurrenceFrequency.weekly => 7 * r.interval,
    RecurrenceFrequency.monthly =>
      146097 * (r.interval ~/ r.interval.gcd(4800)),
  };
  DateTime _proofEnd(
    RecurrenceRule rule,
    List<RecurringSegment> others,
    List<ScheduleEntity> stored,
    Iterable<DateTime> exceptionDates,
  ) {
    if (rule.until != null) return rule.until!;
    if (rule.count != null) return DateTime.utc(9999, 12, 31);
    var days = 1;
    var anchor = rule.start;
    for (final r in [rule, ...others.map((s) => s.rule)]) {
      final period = _period(r);
      days = days ~/ days.gcd(period) * period;
      if (r.start.isAfter(anchor)) anchor = r.start;
      final transitions = tz.getLocation(r.timeZoneId).transitionAt;
      if (transitions.isNotEmpty) {
        final last = DateTime.fromMillisecondsSinceEpoch(
          transitions.last,
          isUtc: true,
        ).add(const Duration(days: 2));
        if (last.isAfter(anchor)) anchor = last;
      }
      if (days > 146097 * 10) {
        throw const RecurrenceValidationException(
          '반복 간격의 조합이 너무 커 충돌 검사를 완료할 수 없어요. 종료 날짜를 지정해 주세요.',
        );
      }
    }
    // After the last finite exception and zone transition, the combined
    // calendar period proves whether the unchanged patterns ever intersect.
    for (final date in [
      ...exceptionDates,
      for (final s in stored) ...[
        s.scheduleTime,
        if (s.recurringSlotKey != null) _civilSlot(s.recurringSlotKey!),
      ],
    ]) {
      final after = date.add(const Duration(days: 2));
      if (after.isAfter(anchor)) anchor = after;
    }
    final end = anchor.add(Duration(days: days + 7));
    if (end.year > 9999) throw const RecurrenceSearchLimit();
    return end;
  }

  @override
  Future<RecurrenceReview> review(
    ScheduleEntity schedule,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    String? replacingSeriesId,
  }) => _review(
    schedule,
    preparation,
    rule,
    replacingSeriesId: replacingSeriesId,
  );

  Future<RecurrenceReview> _review(
    ScheduleEntity schedule,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    String? replacingSeriesId,
    Set<String> ignoredIds = const {},
    Map<String, ScheduleEntity> overrides = const {},
    List<ScheduleEntity> detached = const [],
    Set<String> excludedDays = const {},
    bool skipElapsed = true,
    DateTime? cutoff,
  }) async {
    _validatePreparation(preparation);
    final evaluationNow = cutoff ?? _now();
    // Validate/initialize bundled zones before computing the calendar proof.
    _engine.expand(rule, through: rule.start, limit: 1);
    final allSegments = await getSegments();
    final segments = allSegments
        .where(
          (s) =>
              s.seriesId != replacingSeriesId &&
              (s.beforeSlot == null || s.beforeSlot!.isAfter(rule.start)),
        )
        .toList();
    final replacementIds = allSegments
        .where((s) => s.seriesId == replacingSeriesId)
        .map((s) => s.id)
        .toSet();
    final stored = (await db.scheduleDao.getScheduleList()).map(
      (r) => r.toScheduleEntity(),
    );
    final relevant = stored
        .where(
          (s) =>
              !ignoredIds.contains(s.id) &&
              (!replacementIds.contains(s.recurringSegmentId) || _protected(s)),
        )
        .toList();
    final exclusionsBySegment = <String, Set<String>>{};
    for (final segment in segments) {
      exclusionsBySegment[segment.id] = await _excluded(segment.id);
    }
    final through = _proofEnd(
      rule,
      segments,
      [...relevant, ...detached, ...overrides.values],
      exclusionsBySegment.values.expand((keys) => keys).map(_civilSlot),
    );
    final candidate = _engine.expand(
      rule,
      through: through,
      leadTime: _lead(schedule, preparation),
      preparationNotBeforeUtc: skipElapsed ? (cutoff ?? _now()) : null,
    );
    if (candidate.slots.isEmpty) {
      throw const RecurrenceValidationException('이 조건으로 만들 수 있는 일정이 없어요.');
    }
    if (rule.count != null && candidate.slots.last.ordinal != rule.count) {
      throw const RecurrenceValidationException(
        '지정한 횟수의 일정을 만들 수 없어요. 종료 조건을 확인해 주세요.',
      );
    }
    final candidates = candidate.slots
        .where((slot) => !excludedDays.contains(_day(slot.civilTime)))
        .toList();
    final preparationTimes = <String, Duration>{};
    Future<Duration> definitionTime(String id) async =>
        preparationTimes[id] ??= (await getPreparation(id)).totalDuration;
    final proposed = <({RecurrenceSlot slot, _BusyInterval interval})>[];
    for (final slot in candidates) {
      var value = schedule.copyWith(
        id: slot.key,
        scheduleTime: slot.civilTime,
        timeZoneId: rule.timeZoneId,
        occurrenceOffsetSeconds: slot.offsetSeconds,
        clearPreparationDefinition: true,
        recurringOverrides: '',
      );
      final old = overrides[_day(slot.civilTime)];
      if (old != null) value = _mergeOverrides(value, old);
      final prep = value.preparationDefinitionId == null
          ? preparation.totalDuration
          : await definitionTime(value.preparationDefinitionId!);
      final instant = ScheduleTimeResolver.resolve(
        value,
        nowUtc: evaluationNow,
      ).instantUtc;
      if (instant == null) {
        throw const RecurrenceValidationException('일정 시간대와 발생 시각을 확인해 주세요.');
      }
      proposed.add((
        slot: slot,
        interval: _BusyInterval(
          value,
          instant.subtract(
            prep + value.moveTime + (value.scheduleSpareTime ?? Duration.zero),
          ),
          instant,
        ),
      ));
    }
    if (!skipElapsed &&
        proposed.any((p) => p.interval.start.isBefore(_now().toUtc()))) {
      throw const RecurrenceValidationException(
        '변경한 회차의 준비 시작 시각이 지났어요. 시간을 조정해 주세요.',
      );
    }
    proposed.sort((a, b) => a.interval.start.compareTo(b.interval.start));
    final conflicts = <RecurrenceConflict>[];
    var persistent = false;
    // Validate effective overrides against each other, not just base rule times.
    for (var i = 0; i < proposed.length; i++) {
      final a = proposed[i];
      for (
        var j = i + 1;
        j < proposed.length &&
            !proposed[j].interval.start.isAfter(a.interval.instant);
        j++
      ) {
        final b = proposed[j];
        if (!_overlaps(a.interval, b.interval)) continue;
        conflicts.add(
          RecurrenceConflict(
            slot: b.slot,
            other: a.interval.schedule,
            otherSlotKey: a.slot.key,
          ),
        );
        if (rule.count == null &&
            rule.until == null &&
            a.interval.schedule.recurringOverrides.isEmpty &&
            b.interval.schedule.recurringOverrides.isEmpty) {
          persistent = true;
        }
      }
      if (persistent) break;
    }
    final byId = {
      for (final s in [...relevant, ...detached]) s.id: s,
    };
    final unboundedIds = <String>{};
    if (proposed.isNotEmpty && !persistent) {
      final firstInstant = proposed.first.interval.start;
      final lastInstant = proposed
          .map((p) => p.interval.instant)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      for (final segment in segments) {
        preparationTimes[segment.preparationId] =
            segment.preparation.totalDuration;
        if (segment.rule.count == null &&
            segment.rule.until == null &&
            segment.beforeSlot == null) {
          unboundedIds.add(segment.id);
        }
        final otherSlots = _expandSegment(
          segment,
          lastInstant.add(segment.leadTime + const Duration(days: 2)),
          from: firstInstant.subtract(const Duration(days: 2)),
          excluded: exclusionsBySegment[segment.id]!,
        );
        for (final slot in otherSlots) {
          final value = _occurrence(segment, slot);
          if (!ignoredIds.contains(value.id)) {
            byId.putIfAbsent(value.id, () => value);
          }
        }
      }
      final defaultPrep = await db.preparationUserDao
          .getPreparationUsersByUserId(localProfileId);
      final intervals = <_BusyInterval>[];
      for (final value in byId.values) {
        final instant = ScheduleTimeResolver.resolve(
          value,
          nowUtc: evaluationNow,
        ).instantUtc;
        if (instant == null) continue;
        Duration prep;
        if (value.preparationDefinitionId != null) {
          prep = await definitionTime(value.preparationDefinitionId!);
        } else {
          final own = await db.preparationScheduleDao
              .getPreparationSchedulesByScheduleId(value.id);
          prep = own.preparationStepList.isEmpty
              ? defaultPrep.totalDuration
              : own.totalDuration;
        }
        intervals.add(
          _BusyInterval(
            value,
            instant.subtract(
              prep +
                  value.moveTime +
                  (value.scheduleSpareTime ?? Duration.zero),
            ),
            instant,
          ),
        );
      }
      intervals.sort((a, b) => a.start.compareTo(b.start));
      var index = 0;
      for (final proposedValue in proposed) {
        final value = proposedValue.interval;
        while (index < intervals.length &&
            !intervals[index].instant.isAfter(value.start) &&
            intervals[index].instant != value.instant) {
          index++;
        }
        for (
          var j = index;
          j < intervals.length && !intervals[j].start.isAfter(value.instant);
          j++
        ) {
          final other = intervals[j];
          if (_overlaps(value, other)) {
            conflicts.add(
              RecurrenceConflict(
                slot: proposedValue.slot,
                other: other.schedule,
              ),
            );
            if (rule.count == null &&
                rule.until == null &&
                value.schedule.recurringOverrides.isEmpty &&
                other.schedule.recurringOverrides.isEmpty &&
                unboundedIds.contains(other.schedule.recurringSegmentId)) {
              persistent = true;
            }
          }
        }
        if (persistent) break;
      }
    }
    // Keep the complete proof local; the form only needs previews and every
    // conflict key that can be explicitly excluded.
    proposed.sort((a, b) => a.interval.instant.compareTo(b.interval.instant));
    final conflictKeys = conflicts
        .expand(
          (c) => [c.slot.key, if (c.otherSlotKey != null) c.otherSlotKey!],
        )
        .toSet();
    final finite = rule.count != null || rule.until != null;
    var previewCount = 0;
    final visible = proposed
        .where(
          (p) =>
              finite ||
              conflictKeys.contains(p.slot.key) ||
              previewCount++ < 20,
        )
        .toList();
    return RecurrenceReview(
      slots: visible.map((p) => p.slot).toList(),
      occurrences: {
        for (final p in visible)
          p.slot.key: RecurrencePreviewOccurrence(
            p.interval.schedule,
            p.interval.start,
          ),
      },
      totalOccurrences: finite ? candidates.length : null,
      skipped: candidate.skipped,
      conflicts: conflicts,
      persistentConflict: persistent,
      detached: detached,
    );
  }

  void _requireClear(RecurrenceReview review, Set<String> excluded) {
    final conflictKeys = review.conflicts
        .expand(
          (c) => [c.slot.key, if (c.otherSlotKey != null) c.otherSlotKey!],
        )
        .toSet();
    if (excluded.any((key) => !conflictKeys.contains(key))) {
      throw RecurrenceNeedsReview(review);
    }
    if (review.persistentConflict ||
        review.conflicts.any(
          (c) =>
              !excluded.contains(c.slot.key) &&
              !excluded.contains(c.otherSlotKey),
        )) {
      throw RecurrenceNeedsReview(review);
    }
  }

  void _checkReviewedFirst(
    RecurrenceReview review,
    Set<String> excluded,
    String? expected,
  ) {
    final remaining = review.slots.where((s) => !excluded.contains(s.key));
    if (expected != null &&
        (remaining.isEmpty || remaining.first.key != expected)) {
      throw RecurrenceNeedsReview(review);
    }
  }

  @override
  Future<void> create(
    ScheduleEntity schedule,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    Set<String> excludedSlots = const {},
    String? reviewedFirstSlotKey,
  }) async {
    await db.writeTransaction(() async {
      final existing = await (db.select(
        db.recurringScheduleSegments,
      )..where((t) => t.seriesId.equals(schedule.id))).get();
      if (existing.isNotEmpty) {
        throw const ScheduleSaveRejected(ScheduleSaveFailure.conflict);
      }
      final cutoff = _now();
      final check = await _review(schedule, preparation, rule, cutoff: cutoff);
      _requireClear(check, excludedSlots);
      _checkReviewedFirst(check, excludedSlots, reviewedFirstSlotKey);
      final first = _engine.expand(
        rule,
        through: rule.until ?? DateTime.utc(9999, 12, 31),
        limit: 1,
        preparationNotBeforeUtc: cutoff,
        leadTime: _lead(schedule, preparation),
        excludedKeys: excludedSlots,
      );
      if (first.slots.isEmpty) {
        throw const RecurrenceValidationException('제외 후 남는 일정이 없어요.');
      }
      final id = _uuid.v7();
      final preparationId = await _savePreparation(
        preparation,
        schedule.id,
        schedule.scheduleName,
      );
      await _insertSegment(
        id: id,
        seriesId: schedule.id,
        rule: rule,
        schedule: schedule,
        preparationId: preparationId,
        fromSlot: rule.start,
        cutoff: cutoff,
      );
      final excluded = check.slots.where((s) => excludedSlots.contains(s.key));
      for (final slot in excluded) {
        await _exclude(id, slot.key, slot.ordinal);
      }
      await _materializeSegment(
        await getSegment(id),
        rule.start,
        DateTime.utc(math.min(9999, rule.start.year + 100), 12, 31),
        limit: 60,
      );
      await _changed();
    });
  }

  Future<void> _insertSegment({
    required String id,
    required String seriesId,
    required RecurrenceRule rule,
    required ScheduleEntity schedule,
    required String preparationId,
    required DateTime fromSlot,
    DateTime? cutoff,
  }) async {
    await db
        .into(db.recurringScheduleSegments)
        .insert(
          RecurringScheduleSegmentsCompanion.insert(
            id: id,
            seriesId: seriesId,
            ruleJson: jsonEncode(RecurrenceCodec.ruleToJson(rule)),
            scheduleJson: jsonEncode(
              RecurrenceCodec.scheduleToJson(
                schedule.copyWith(
                  place: PlaceEntity(
                    id: _uuid.v7(),
                    placeName: schedule.place.placeName,
                  ),
                ),
              ),
            ),
            preparationId: preparationId,
            fromSlot: fromSlot.toIso8601String(),
            createdAt: _now(),
            preparationNotBefore: Value(cutoff),
          ),
        );
  }

  Future<void> _exclude(String id, String key, int ordinal) => db
      .into(db.recurringScheduleExclusions)
      .insertOnConflictUpdate(
        RecurringScheduleExclusionsCompanion.insert(
          segmentId: id,
          slotKey: key,
          ordinal: ordinal,
        ),
      );
  Future<void> _changed() => db.userDao.markDurableDataChanged(localProfileId);

  @override
  Future<void> materialize(
    DateTime from,
    DateTime through, {
    int? perSeriesLimit,
  }) async {
    await db.writeTransaction(() async {
      for (final segment in await getSegments()) {
        if (segment.beforeSlot != null &&
            !segment.beforeSlot!.isAfter(RecurrenceRule.civilTime(from))) {
          continue;
        }
        await _materializeSegment(
          segment,
          from,
          through,
          limit: perSeriesLimit,
        );
      }
    });
  }

  Future<void> _materializeSegment(
    RecurringSegment s,
    DateTime from,
    DateTime through, {
    int? limit,
    Map<String, ScheduleEntity> overrides = const {},
  }) async {
    // Retained unknown-zone history is not a request to regenerate its past.
    // Do this before engine lookup, including explicit historical queries.
    if (!TimeZoneRules.contains(s.rule.timeZoneId) &&
        RecurrenceReferencePolicy.hasNoFutureGeneration(
          rule: s.rule,
          fromSlot: s.fromSlot,
          beforeSlot: s.beforeSlot,
          nowUtc: _now().toUtc(),
        )) {
      return;
    }
    final slots = _expandSegment(
      s,
      through,
      from: from,
      limit: limit,
      excluded: await _excluded(s.id),
    );
    for (final slot in slots) {
      var schedule = _occurrence(s, slot);
      final existing =
          await (db.select(db.schedules)..where(
                (t) =>
                    t.id.equals(schedule.id) |
                    (t.recurringSegmentId.equals(s.id) &
                        t.recurringSlotKey.equals(slot.key)),
              ))
              .getSingleOrNull();
      if (existing != null) continue;
      final old = overrides[_day(slot.civilTime)];
      if (old != null) schedule = _mergeOverrides(schedule, old);
      await db.scheduleDao.createSchedule(schedule.toScheduleWithPlaceRow());
    }
  }

  ScheduleEntity _mergeOverrides(ScheduleEntity base, ScheduleEntity old) {
    final mask = old.recurringOverrides.split(',').toSet();
    return base.copyWith(
      scheduleName: mask.contains('name') ? old.scheduleName : null,
      scheduleTime: mask.contains('time') ? old.scheduleTime : null,
      timeZoneId: mask.contains('time') ? old.timeZoneId : null,
      occurrenceOffsetSeconds: mask.contains('time')
          ? old.occurrenceOffsetSeconds
          : null,
      place: mask.contains('place') ? old.place : null,
      moveTime: mask.contains('move') ? old.moveTime : null,
      scheduleSpareTime: mask.contains('spare') ? old.scheduleSpareTime : null,
      scheduleNote: mask.contains('note') ? old.scheduleNote : null,
      preparationDefinitionId: mask.contains('preparation')
          ? old.preparationDefinitionId
          : null,
      recurringOverrides: old.recurringOverrides,
    );
  }

  @override
  Future<void> updateOccurrence(
    ScheduleEntity original,
    ScheduleEntity updated,
    PreparationEntity preparation, {
    required bool preparationChanged,
  }) async {
    await db.writeTransaction(() async {
      final current = (await db.scheduleDao.getScheduleById(
        original.id,
      )).toScheduleEntity();
      if (_protected(current)) {
        throw const RecurrenceValidationException('진행 중이거나 지난 회차는 변경할 수 없어요.');
      }
      final occurrences = CivilTimeResolver.resolve(
        updated.scheduleTime,
        updated.timeZoneId,
      );
      final singleRule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        start: updated.scheduleTime,
        timeZoneId: updated.timeZoneId,
        count: 1,
        repeatedTime:
            occurrences.length > 1 &&
                occurrences.last.offsetSeconds ==
                    updated.occurrenceOffsetSeconds
            ? RepeatedCivilTime.second
            : RepeatedCivilTime.first,
      );
      final singleReview = await _review(
        updated,
        preparation,
        singleRule,
        ignoredIds: {current.id},
      );
      _requireClear(singleReview, const {});
      final mask = current.recurringOverrides
          .split(',')
          .where((v) => v.isNotEmpty)
          .toSet();
      if (current.scheduleName != updated.scheduleName) mask.add('name');
      if (current.scheduleTime != updated.scheduleTime ||
          current.timeZoneId != updated.timeZoneId ||
          current.occurrenceOffsetSeconds != updated.occurrenceOffsetSeconds) {
        mask.add('time');
      }
      if (current.place != updated.place) mask.add('place');
      if (current.moveTime != updated.moveTime) mask.add('move');
      if (current.scheduleSpareTime != updated.scheduleSpareTime) {
        mask.add('spare');
      }
      if (current.scheduleNote != updated.scheduleNote) mask.add('note');
      var prep = current.preparationDefinitionId;
      if (preparationChanged) {
        mask.add('preparation');
        prep = await _savePreparation(
          preparation,
          current.id,
          updated.scheduleName,
          scope: 'occurrence',
        );
      }
      final next = updated.copyWith(
        place: current.place != updated.place
            ? PlaceEntity(id: _uuid.v7(), placeName: updated.place.placeName)
            : current.place,
        recurringSegmentId: current.recurringSegmentId,
        recurringSlotKey: current.recurringSlotKey,
        recurringOrdinal: current.recurringOrdinal,
        recurringOverrides: (mask.toList()..sort()).join(','),
        preparationDefinitionId: prep,
        preparationMode: SchedulePreparationMode.custom,
        isChanged: true,
      );
      await db.scheduleDao.updateScheduleWithPlace(
        next.toScheduleWithPlaceRow(),
      );
      await _changed();
    });
  }

  Future<_FollowingPlan> _followingPlan(
    ScheduleEntity original,
    ScheduleEntity updated,
    PreparationEntity preparation,
    RecurrenceRule requested,
    bool countChanged,
  ) async {
    final current = (await db.scheduleDao.getScheduleById(
      original.id,
    )).toScheduleEntity();
    final segment = await getSegment(current.recurringSegmentId!);
    final anchor = _civilSlot(current.recurringSlotKey!);
    if (RecurrenceRule.civilDate(
      requested.start,
    ).isBefore(RecurrenceRule.civilDate(anchor))) {
      throw const RecurrenceValidationException('선택한 회차 이전으로 시작 날짜를 옮길 수 없어요.');
    }
    final series = (await getSegments())
        .where((s) => s.seriesId == segment.seriesId)
        .toList();
    final segmentIds = series.map((s) => s.id).toSet();
    final stored = (await db.scheduleDao.getScheduleList())
        .map((r) => r.toScheduleEntity())
        .where(
          (s) =>
              segmentIds.contains(s.recurringSegmentId) &&
              s.recurringSlotKey != null &&
              !_civilSlot(s.recurringSlotKey!).isBefore(anchor),
        )
        .toList();
    final protected = stored.where(_protected).toList();
    final overrides = stored
        .where((s) => !_protected(s) && s.recurringOverrides.isNotEmpty)
        .toList();
    int? remaining;
    if (!countChanged && segment.rule.count != null) {
      remaining = 0;
      for (final s in series) {
        if (s.beforeSlot != null && !s.beforeSlot!.isAfter(anchor)) continue;
        if (s.rule.count == null) {
          remaining = null;
          break;
        }
        remaining =
            remaining! +
            _expandSegment(s, DateTime.utc(9999, 12, 31), from: anchor).length;
      }
    } else {
      remaining = requested.count;
    }
    final exclusions = <String, int>{};
    for (final s in series) {
      for (final e in await (db.select(
        db.recurringScheduleExclusions,
      )..where((t) => t.segmentId.equals(s.id))).get()) {
        final civil = _civilSlot(e.slotKey);
        if (!civil.isBefore(anchor) &&
            s.includes(
              RecurrenceSlot(
                civilTime: civil,
                instantUtc: civil,
                offsetSeconds: 0,
                ordinal: e.ordinal,
              ),
            )) {
          exclusions[_day(civil)] = e.ordinal;
        }
      }
    }
    // Protected slots consume their place just like explicit exclusions. If a
    // new rule no longer matches their day, reserve that part of the budget.
    for (final value in protected) {
      exclusions[_day(_civilSlot(value.recurringSlotKey!))] =
          value.recurringOrdinal!;
    }
    final target = remaining;
    var detached = <ScheduleEntity>[];
    var unmatchedDeleted = 0;
    List<RecurrenceSlot> candidate = [];
    RecurrenceRule? rule;
    // Reducing the budget can move a changed occurrence outside the new end.
    // Re-evaluate until all detached/consumed slots have been accounted for.
    for (
      var iteration = 0;
      iteration <= overrides.length + exclusions.length + 1;
      iteration++
    ) {
      final count = target == null
          ? null
          : math.max(0, target - detached.length - unmatchedDeleted);
      if (count == 0) {
        rule = null;
        candidate = [];
      } else {
        rule = requested.withStartAndEnd(
          count: count,
          until: count == null ? requested.until : null,
        );
        candidate = _engine
            .expand(
              rule,
              through:
                  rule.until ??
                  (rule.count == null
                      ? DateTime.utc(
                          math.min(9999, rule.start.year + 400),
                          12,
                          31,
                        )
                      : DateTime.utc(9999, 12, 31)),
            )
            .slots;
      }
      final days = candidate.map((s) => _day(s.civilTime)).toSet();
      final nextDetached = overrides
          .where((s) => !days.contains(_day(_civilSlot(s.recurringSlotKey!))))
          .toList();
      final nextUnmatched = exclusions.keys
          .where((d) => !days.contains(d))
          .length;
      if (nextDetached.length == detached.length &&
          nextUnmatched == unmatchedDeleted) {
        detached = nextDetached;
        break;
      }
      detached = nextDetached;
      unmatchedDeleted = nextUnmatched;
    }
    final effective = candidate
        .where((slot) => !exclusions.containsKey(_day(slot.civilTime)))
        .toList();
    if (effective.isNotEmpty &&
        effective.first.instantUtc
            .subtract(_lead(updated, preparation))
            .isBefore(_now().toUtc())) {
      throw const RecurrenceValidationException(
        '변경한 첫 회차의 준비 시작 시각이 지났어요. 시간을 조정해 주세요.',
      );
    }
    return _FollowingPlan(
      series,
      segment,
      anchor,
      rule,
      detached,
      {for (final s in overrides) _day(_civilSlot(s.recurringSlotKey!)): s},
      exclusions.keys.toSet(),
      protected,
      candidate,
    );
  }

  @override
  Future<RecurrenceReview> reviewFollowing(
    ScheduleEntity original,
    ScheduleEntity updated,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    bool countChanged = false,
  }) async {
    final plan = await _followingPlan(
      original,
      updated,
      preparation,
      rule,
      countChanged,
    );
    final check = plan.rule == null
        ? const RecurrenceReview(slots: [], skipped: [])
        : await _review(
            updated,
            preparation,
            plan.rule!,
            replacingSeriesId: plan.segment.seriesId,
            overrides: plan.overrides,
            detached: plan.detached,
            excludedDays: plan.excludedDays,
            skipElapsed: false,
          );
    return RecurrenceReview(
      slots: check.slots,
      occurrences: check.occurrences,
      totalOccurrences: plan.rule == null ? 0 : check.totalOccurrences,
      skipped: check.skipped,
      conflicts: check.conflicts,
      persistentConflict: check.persistentConflict,
      detached: plan.detached,
    );
  }

  @override
  Future<void> updateFollowing(
    ScheduleEntity original,
    ScheduleEntity updated,
    PreparationEntity preparation,
    RecurrenceRule rule, {
    bool countChanged = false,
    Set<String> excludedSlots = const {},
    String? reviewedFirstSlotKey,
    bool confirmDetached = false,
  }) async {
    await db.writeTransaction(() async {
      final plan = await _followingPlan(
        original,
        updated,
        preparation,
        rule,
        countChanged,
      );
      final check = await reviewFollowing(
        original,
        updated,
        preparation,
        rule,
        countChanged: countChanged,
      );
      _requireClear(check, excludedSlots);
      _checkReviewedFirst(check, excludedSlots, reviewedFirstSlotKey);
      if (plan.detached.isNotEmpty && !confirmDetached) {
        throw RecurrenceNeedsReview(check);
      }
      await _closeFollowing(plan.series, plan.anchor);
      final segmentIds = plan.series.map((s) => s.id).toSet();
      final detachIds = plan.detached.map((s) => s.id).toSet();
      final rows = (await db.scheduleDao.getScheduleList()).map(
        (r) => r.toScheduleEntity(),
      );
      for (final s in rows) {
        if (!segmentIds.contains(s.recurringSegmentId) ||
            s.recurringSlotKey == null ||
            _civilSlot(s.recurringSlotKey!).isBefore(plan.anchor) ||
            _protected(s)) {
          continue;
        }
        if (detachIds.contains(s.id)) {
          await db.scheduleDao.updateScheduleWithPlace(
            s
                .copyWith(clearRecurring: true, recurringOverrides: '')
                .toScheduleWithPlaceRow(),
          );
          await (db.update(
            db.schedules,
          )..where((t) => t.id.equals(s.id))).write(
            const SchedulesCompanion(
              recurringSegmentId: Value(null),
              recurringSlotKey: Value(null),
              recurringOrdinal: Value(null),
            ),
          );
        } else {
          await _removeRow(s.id);
        }
      }
      if (plan.rule != null) {
        final prepId = await _savePreparation(
          preparation,
          plan.segment.seriesId,
          updated.scheduleName,
        );
        final id = _uuid.v7();
        await _insertSegment(
          id: id,
          seriesId: plan.segment.seriesId,
          rule: plan.rule!,
          schedule: updated,
          preparationId: prepId,
          fromSlot: plan.rule!.start,
        );
        for (final slot in plan.candidates) {
          if (plan.excludedDays.contains(_day(slot.civilTime)) ||
              excludedSlots.contains(slot.key)) {
            await _exclude(id, slot.key, slot.ordinal);
          }
        }
        final segment = await getSegment(id);
        // Preserve all explicit future overrides even beyond the notification window.
        var through = DateTime.utc(
          math.min(9999, rule.start.year + 100),
          12,
          31,
        );
        await _materializeSegment(
          segment,
          rule.start,
          through,
          limit: 60,
          overrides: plan.overrides,
        );
        for (final slot in plan.candidates.where(
          (s) => plan.overrides.containsKey(_day(s.civilTime)),
        )) {
          await _materializeSegment(
            segment,
            slot.civilTime,
            slot.civilTime,
            overrides: plan.overrides,
          );
        }
      }
      await _changed();
    });
  }

  Future<void> _closeFollowing(
    List<RecurringSegment> segments,
    DateTime anchor,
  ) async {
    for (final s in segments) {
      if (s.beforeSlot != null && !s.beforeSlot!.isAfter(anchor)) continue;
      final boundary = anchor.isBefore(s.fromSlot) ? s.fromSlot : anchor;
      await (db.update(
        db.recurringScheduleSegments,
      )..where((t) => t.id.equals(s.id))).write(
        RecurringScheduleSegmentsCompanion(
          beforeSlot: Value(boundary.toIso8601String()),
        ),
      );
    }
  }

  Future<void> _removeRow(String id) async {
    await removeScheduleRow(db, id);
  }

  @override
  Future<void> delete(
    ScheduleEntity occurrence,
    RecurringEditScope scope,
  ) async {
    await db.writeTransaction(() async {
      final current = (await db.scheduleDao.getScheduleById(
        occurrence.id,
      )).toScheduleEntity();
      if (scope == RecurringEditScope.occurrence) {
        if (current.isStarted) {
          throw const RecurrenceValidationException('진행 중인 준비를 먼저 종료해 주세요.');
        }
        await _exclude(
          current.recurringSegmentId!,
          current.recurringSlotKey!,
          current.recurringOrdinal!,
        );
        await removeScheduleOwnedContent(db, current.id);
      } else {
        final segment = await getSegment(current.recurringSegmentId!);
        final series = (await getSegments())
            .where((s) => s.seriesId == segment.seriesId)
            .toList();
        final anchor = _civilSlot(current.recurringSlotKey!);
        await _closeFollowing(series, anchor);
        final ids = series.map((s) => s.id).toSet();
        for (final r in await db.scheduleDao.getScheduleList()) {
          final s = r.toScheduleEntity();
          if (ids.contains(s.recurringSegmentId) &&
              s.recurringSlotKey != null &&
              !_civilSlot(s.recurringSlotKey!).isBefore(anchor) &&
              !_protected(s)) {
            await removeScheduleOwnedContent(db, s.id);
          }
        }
      }
      await _changed();
    });
  }
}

bool _overlaps(_BusyInterval a, _BusyInterval b) =>
    a.instant == b.instant ||
    (a.start.isBefore(b.instant) && b.start.isBefore(a.instant));

class _BusyInterval {
  const _BusyInterval(this.schedule, this.start, this.instant);
  final ScheduleEntity schedule;
  final DateTime start;
  final DateTime instant;
}

class _FollowingPlan {
  const _FollowingPlan(
    this.series,
    this.segment,
    this.anchor,
    this.rule,
    this.detached,
    this.overrides,
    this.excludedDays,
    this.protected,
    this.candidates,
  );
  final List<RecurringSegment> series;
  final RecurringSegment segment;
  final DateTime anchor;
  final RecurrenceRule? rule;
  final List<ScheduleEntity> detached;
  final Map<String, ScheduleEntity> overrides;
  final Set<String> excludedDays;
  final List<ScheduleEntity> protected;
  final List<RecurrenceSlot> candidates;
}

DateTime _civilSlot(String value) => CivilDateTime.parse(value).toUtcCarrier();
