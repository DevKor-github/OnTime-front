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
      final scheduleModel = await into(
        db.schedules,
      ).insertReturning(scheduleWithPlace.schedule.toCompanion(false));
      return ScheduleWithPlace(
        schedule: scheduleModel,
        place: scheduleWithPlace.place,
      );
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

  Future<Schedule> updateSchedule(Schedule scheduleModel) async {
    final scheduleList =
        await (update(db.schedules)
              ..where((tbl) => tbl.id.equals(scheduleModel.id)))
            .writeReturning(scheduleModel.toCompanion(true));
    assert(scheduleList.length == 1);
    return scheduleList.first;
  }

  Future<ScheduleWithPlace> updateScheduleWithPlace(
    ScheduleWithPlace value,
  ) async {
    return transaction(() async {
      await into(
        db.places,
      ).insertOnConflictUpdate(value.place.toCompanion(false));
      await (update(db.schedules)
            ..where((table) => table.id.equals(value.schedule.id)))
          .write(value.schedule.toCompanion(true));
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
    final query = select(db.schedules).join([
      leftOuterJoin(db.places, db.places.id.equalsExp(db.schedules.placeId)),
    ])..orderBy([OrderingTerm.asc(db.schedules.scheduleTime)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          ScheduleWithPlace(
            schedule: row.readTable(db.schedules),
            place: row.readTable(db.places),
          ),
      ],
    );
  }
}
