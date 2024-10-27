import 'package:drift/drift.dart';
import 'package:on_time_front/config/database.dart';

import 'package:on_time_front/data/tables/places_table.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';

import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

part 'schedule_dao.g.dart';

@DriftAccessor(tables: [Schedules, Places, Users])
class ScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduleDaoMixin {
  final AppDatabase db;

  ScheduleDao(this.db) : super(db);

  Future<void> createSchedule(ScheduleEntity scheduleEntity) async {
    await into(db.schedules).insert(
      scheduleEntity.toModel().toCompanion(false),
    );
  }

  Future<void> createPlace(PlaceEntity placeEntity) async {
    await into(db.places).insert(
      placeEntity.toModel().toCompanion(false),
    );
  }

  Future<void> createUser(UserEntity userentity) async {
    await into(db.users).insert(
      userentity.toModel().toCompanion(false),
    );
  }

  Future<List<ScheduleEntity>> getScheduleList() async {
    final List<Schedule> query = await select(db.schedules).get();
    final List<ScheduleEntity> scheduleList = [];

    Future.forEach(query, (schedule) async {
      final place = await (select(db.places)
            ..where((tbl) => tbl.id.equals(schedule.placeId)))
          .getSingle();

      final user = await (select(db.users)
            ..where((tbl) => tbl.id.equals(schedule.userId)))
          .getSingle();

      scheduleList.add(ScheduleEntity.fromModel(
        schedule,
        user,
        place,
      ));
    });
    return scheduleList;
  }
}
