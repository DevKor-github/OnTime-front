import 'schedule_owned_content_cleanup.dart';
import 'package:on_time_front/domain/recurrence/recurrence_reference_policy.dart';
import 'package:on_time_front/domain/entities/schedule_not_found.dart';
import 'package:drift/drift.dart';
import 'package:on_time_front/data/tables/places_table.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';
import '/core/database/database.dart';
import 'package:on_time_front/core/utils/json_converters/duration_json_converters.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';

part 'schedule_dao.g.dart';

@DriftAccessor(tables: [Schedules, Places])
class ScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduleDaoMixin {
  final AppDatabase db;

  ScheduleDao(this.db) : super(db);

  Future<ScheduleWithPlace> createSchedule(
    ScheduleWithPlace scheduleWithPlace,
  ) async {
    return transaction(() async {
      await into(
        db.places,
      ).insertOnConflictUpdate(scheduleWithPlace.place.toCompanion(false));
      await into(db.schedules).insert(
        _withoutConcurrencyMetadata(
          scheduleWithPlace.schedule.toCompanion(false),
        ),
      );
      return getScheduleById(scheduleWithPlace.schedule.id);
    });
  }

  Future<void> deleteSchedule(Schedule scheduleModel) async {
    await transaction(() => removeScheduleOwnedContent(db, scheduleModel.id));
  }

  Future<ScheduleWithPlace> getScheduleById(String id) async {
    try {
      final query = await (select(db.schedules).join([
        leftOuterJoin(db.places, db.places.id.equalsExp(db.schedules.placeId)),
        leftOuterJoin(
          db.recurringScheduleSegments,
          db.recurringScheduleSegments.id.equalsExp(
            db.schedules.recurringSegmentId,
          ),
        ),
      ])..where(db.schedules.id.equals(id))).getSingleOrNull();
      if (query == null) throw ScheduleNotFound(id);
      return _readJoined(query);
    } catch (e) {
      rethrow;
    }
  }

  SchedulesCompanion _withoutConcurrencyMetadata(SchedulesCompanion values) =>
      values.copyWith(
        requiresStartConfirmation: const Value.absent(),
        aggregateIncarnation: const Value.absent(),
        aggregateVersion: const Value.absent(),
        lastMutationId: const Value.absent(),
        lastMutationDigest: const Value.absent(),
        lastMutationVersion: const Value.absent(),
      );

  Future<Schedule> updateSchedule(Schedule scheduleModel) =>
      transaction(() async {
        final changed =
            await (update(
              db.schedules,
            )..where((t) => t.id.equals(scheduleModel.id))).write(
              _withoutConcurrencyMetadata(scheduleModel.toCompanion(true)),
            );
        if (changed != 1) throw ScheduleNotFound(scheduleModel.id);
        return (await getScheduleById(scheduleModel.id)).schedule;
      });

  Future<ScheduleWithPlace> updateScheduleWithPlace(
    ScheduleWithPlace value,
  ) async {
    return transaction(() async {
      await into(
        db.places,
      ).insertOnConflictUpdate(value.place.toCompanion(false));
      await (update(db.schedules)
            ..where((table) => table.id.equals(value.schedule.id)))
          .write(_withoutConcurrencyMetadata(value.schedule.toCompanion(true)));
      return getScheduleById(value.schedule.id);
    });
  }

  Future<List<ScheduleWithPlace>> getSchedulesByDate(
    DateTime startDate,
    DateTime? endDate,
  ) async {
    final query =
        select(db.schedules).join([
          leftOuterJoin(
            db.places,
            db.places.id.equalsExp(db.schedules.placeId),
          ),
          leftOuterJoin(
            db.recurringScheduleSegments,
            db.recurringScheduleSegments.id.equalsExp(
              db.schedules.recurringSegmentId,
            ),
          ),
        ])..where(
          db.schedules.scheduleTime.isBiggerOrEqualValue(
                const CivilDateTimeSqlConverter().toSql(startDate),
              ) &
              (endDate == null
                  ? Constant<bool>(true)
                  : db.schedules.scheduleTime.isSmallerThanValue(
                      const CivilDateTimeSqlConverter().toSql(endDate),
                    )),
        );
    final result = await query.get();
    final List<ScheduleWithPlace> scheduleList = [];

    await Future.forEach(result, (schedule) async {
      scheduleList.add(_readJoined(schedule));
    });
    return scheduleList;
  }

  Future<List<ScheduleWithPlace>> getScheduleList({int? limit}) async {
    final query = select(db.schedules).join([
      leftOuterJoin(db.places, db.places.id.equalsExp(db.schedules.placeId)),
      leftOuterJoin(
        db.recurringScheduleSegments,
        db.recurringScheduleSegments.id.equalsExp(
          db.schedules.recurringSegmentId,
        ),
      ),
    ]);
    if (limit != null) query.limit(limit);
    final result = await query.get();
    final List<ScheduleWithPlace> scheduleList = [];

    await Future.forEach(result, (schedule) async {
      scheduleList.add(_readJoined(schedule));
    });
    return scheduleList;
  }

  /// Finite materialized references only; this query never expands a rule.
  Future<List<ScheduleWithPlace>> getSeriesReferences(
    String seriesId, {
    required int limit,
  }) async {
    final query =
        select(db.schedules).join([
            leftOuterJoin(
              db.places,
              db.places.id.equalsExp(db.schedules.placeId),
            ),
            innerJoin(
              db.recurringScheduleSegments,
              db.recurringScheduleSegments.id.equalsExp(
                db.schedules.recurringSegmentId,
              ),
            ),
          ])
          ..where(db.recurringScheduleSegments.seriesId.equals(seriesId))
          ..orderBy([OrderingTerm.asc(db.schedules.id)])
          ..limit(limit);
    return (await query.get()).map(_readJoined).toList();
  }

  ScheduleWithPlace _readJoined(TypedResult row) {
    final schedule = row.readTable(db.schedules);
    final segment = row.readTableOrNull(db.recurringScheduleSegments);
    return ScheduleWithPlace(
      schedule: schedule,
      place: row.readTable(db.places),
      retainedRecurringReference: _retained(
        schedule,
        segment?.id,
        segment?.beforeSlot,
      ),
    );
  }

  bool _retained(Schedule schedule, String? segmentId, String? before) {
    if (schedule.recurringSegmentId == null) return false;
    if (segmentId == null || schedule.recurringSlotKey == null) return true;
    return RecurrenceReferencePolicy.isClosedTail(
      schedule.recurringSlotKey!,
      before,
    );
  }

  Stream<List<ScheduleWithPlace>> watchScheduleList() {
    // Trigger-written versions also change when a preparation dependency changes.
    // Drift needs those dependencies explicitly; notifications remain commit-bound.
    return db
        .customSelect(
          'SELECT s.*, p.id AS joined_place_id, p.place_name AS joined_place_name, r.id AS joined_segment_id, r.before_slot AS joined_segment_before FROM schedules s JOIN places p ON p.id=s.place_id LEFT JOIN recurring_schedule_segments r ON r.id=s.recurring_segment_id ORDER BY s.schedule_time ASC',
          readsFrom: {
            db.schedules,
            db.places,
            db.preparationSchedules,
            db.preparationUsers,
            db.preparationTemplates,
            db.preparationTemplateSteps,
            db.preparationDefinitions,
            db.preparationDefinitionSteps,
            db.recurringScheduleSegments,
            db.recurringScheduleExclusions,
          },
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => ScheduleWithPlace(
                  schedule: db.schedules.map(row.data),
                  retainedRecurringReference: _retained(
                    db.schedules.map(row.data),
                    row.readNullable<String>('joined_segment_id'),
                    row.readNullable<String>('joined_segment_before'),
                  ),
                  place: Place(
                    id: row.read<String>('joined_place_id'),
                    placeName: row.read<String>('joined_place_name'),
                  ),
                ),
              )
              .toList(growable: false),
        );
  }
}
