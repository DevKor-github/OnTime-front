import 'package:drift/drift.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import '/core/database/database.dart';

import 'package:on_time_front/data/tables/preparation_schedule_table.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:on_time_front/data/tables/places_table.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';

part 'preparation_schedule_dao.g.dart';

@DriftAccessor(tables: [PreparationSchedules, Schedules, Users, Places])
class PreparationScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$PreparationScheduleDaoMixin {
  final AppDatabase db;

  PreparationScheduleDao(this.db) : super(db);

  Future<void> createPreparationSchedule(
      PreparationEntity preparationEntity, String scheduleId) async {
    for (var step in preparationEntity.preparationStepList) {
      await into(db.preparationSchedules).insert(
        step.toPreparationScheduleModel(scheduleId).toCompanion(false),
      );
    }
  }

  Future<List<PreparationEntity>> getPreparationSchedulesByScheduleId(
      String scheduleId) async {
    final List<PreparationSchedule> query =
        await (select(db.preparationSchedules)
              ..where((tbl) => tbl.scheduleId.equals(scheduleId)))
            .get();

    final List<PreparationStepEntity> stepEntities =
        query.map((preparationSchedule) {
      return PreparationStepEntity(
        id: preparationSchedule.id,
        preparationName: preparationSchedule.preparationName,
        preparationTime: preparationSchedule.preparationTime,
        nextPreparationId: preparationSchedule.nextPreparationId,
      );
    }).toList();

    return [PreparationEntity(preparationStepList: stepEntities)];
  }

  Future<PreparationStepEntity> getPreparationStepById(
      String preparationStepId) async {
    final result = await (select(db.preparationSchedules)
          ..where((tbl) => tbl.id.equals(preparationStepId)))
        .getSingle();
    return PreparationStepEntity(
      id: result.id,
      preparationName: result.preparationName,
      preparationTime: result.preparationTime,
      nextPreparationId: result.nextPreparationId,
    );
  }

  Future<void> updatePreparationSchedule(
      PreparationStepEntity stepEntity, String scheduleId) async {
    final preparationSchedule =
        stepEntity.toPreparationScheduleModel(scheduleId);

    await (update(db.preparationSchedules)
          ..where((tbl) => tbl.id.equals(preparationSchedule.id)))
        .write(preparationSchedule);
  }

  Future<void> deletePreparationSchedule(String preparationId) async {
    await (delete(db.preparationSchedules)
          ..where((tbl) => tbl.id.equals(preparationId)))
        .go();
  }
}
