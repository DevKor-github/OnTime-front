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
    await (delete(
      db.schedules,
    )..where((tbl) => tbl.id.equals(scheduleModel.id))).go();
  }

  Future<ScheduleWithPlace> getScheduleById(String id) async {
    try {
      final query = await (select(db.schedules).join([
        leftOuterJoin(db.places, db.places.id.equalsExp(db.schedules.placeId)),
      ])..where(db.schedules.id.equals(id))).getSingleOrNull();
      if (query == null) throw ScheduleNotFound(id);
      return ScheduleWithPlace(
        schedule: query.readTable(db.schedules),
        place: query.readTable(db.places),
      );
    } catch (e) {
      rethrow;
    }
  }

  SchedulesCompanion _withoutConcurrencyMetadata(SchedulesCompanion values) =>
      values.copyWith(
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
      scheduleList.add(
        ScheduleWithPlace(
          schedule: schedule.readTable(db.schedules),
          place: schedule.readTable(db.places),
        ),
      );
    });
    return scheduleList;
  }

  Future<List<ScheduleWithPlace>> getScheduleList() async {
    final query = select(db.schedules).join([
      leftOuterJoin(db.places, db.places.id.equalsExp(db.schedules.placeId)),
    ]);
    final result = await query.get();
    final List<ScheduleWithPlace> scheduleList = [];

    await Future.forEach(result, (schedule) async {
      scheduleList.add(
        ScheduleWithPlace(
          schedule: schedule.readTable(db.schedules),
          place: schedule.readTable(db.places),
        ),
      );
    });
    return scheduleList;
  }

  Stream<List<ScheduleWithPlace>> watchScheduleList() {
    // Trigger-written versions also change when a preparation dependency changes.
    // Drift needs those dependencies explicitly; notifications remain commit-bound.
    return db
        .customSelect(
          'SELECT s.*, p.id AS joined_place_id, p.place_name AS joined_place_name FROM schedules s JOIN places p ON p.id=s.place_id ORDER BY s.schedule_time ASC',
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
