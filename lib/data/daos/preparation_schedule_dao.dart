import 'package:drift/drift.dart';
import 'package:on_time_front/config/database.dart';

import 'package:on_time_front/data/tables/preparation_schedule_table.dart';
import 'package:on_time_front/data/tables/preparation_user_table.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:on_time_front/data/tables/places_table.dart';

import 'package:on_time_front/domain/entities/preparation_schedule_entity.dart';

part 'preparation_schedule_dao.g.dart';

@DriftAccessor(tables: [
  Places,
  Schedules,
  Users,
  PreparationSchedules,
  PreparationUsers,
])
class PreparationScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$PreparationScheduleDaoMixin {
  final AppDatabase db;

  PreparationScheduleDao(this.db) : super(db);

  Future<void> createPreparationSchedule(
      PreparationScheduleEntity preparationScheduleEntity) async {
    await into(db.preparationSchedules).insert(
      preparationScheduleEntity.toModel().toCompanion(false),
    );
  }

  Future<List<PreparationScheduleEntity>> getPreparationSchedulesByScheduleId(
      int scheduleId) async {
    final List<PreparationSchedule> query =
        await (select(db.preparationSchedules)
              ..where((tbl) => tbl.scheduleId.equals(scheduleId)))
            .get();
    final List<PreparationScheduleEntity> preparationScheduleList = [];

    await Future.forEach(query, (preparationSchedule) async {
      final schedule = await (select(db.schedules)
            ..where((tbl) => tbl.id.equals(preparationSchedule.scheduleId)))
          .getSingle();
      final user = await (select(db.users)
            ..where((tbl) => tbl.id.equals(schedule.userId)))
          .getSingle();
      final place = await (select(db.places)
            ..where((tbl) => tbl.id.equals(schedule.placeId)))
          .getSingle();

      preparationScheduleList.add(
        PreparationScheduleEntity.fromModel(
            preparationSchedule, schedule, user, place),
      );
    });

    return preparationScheduleList;
  }
}
