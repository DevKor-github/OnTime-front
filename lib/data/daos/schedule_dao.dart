import 'package:drift/drift.dart';
import '/core/database/database.dart';

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

  Future<void> createSchedule(ScheduleEntity scheduleEntity, int userId) async {
    await into(db.schedules).insert(
      scheduleEntity.toModel(userId).toCompanion(false),
    );
  }

  Future<void> createPlace(PlaceEntity placeEntity) async {
    await db.placeDao.createPlace(placeEntity);
  }

  Future<void> createUser(UserEntity userEntity) async {
    await db.userDao.createUser(userEntity);
  }

  Future<List<ScheduleEntity>> getScheduleList() async {
    final List<Schedule> query = await select(db.schedules).get();
    final List<ScheduleEntity> scheduleList = [];

    await Future.forEach(query, (schedule) async {
      final place = await (select(db.places)
            ..where((tbl) => tbl.id.equals(schedule.placeId)))
          .getSingle();

      scheduleList.add(ScheduleEntity.fromModel(
        schedule,
        place,
      ));
    });
    return scheduleList;
  }
}
