import 'package:drift/drift.dart';
import '/core/database/database.dart';

import 'package:on_time_front/data/tables/preparation_schedule_table.dart';

part 'preparation_schedule_dao.g.dart';

@DriftAccessor(tables: [PreparationSchedules])
class PreparationScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$PreparationScheduleDaoMixin {
  final AppDatabase db;

  PreparationScheduleDao(this.db) : super(db);

  Future<List<PreparationSchedule>> createPreparationSchedule(
      List<PreparationSchedule> preparationStepModel) async {
    final List<PreparationSchedule> preparationScheduleList = [];
    for (var step in preparationStepModel) {
      preparationScheduleList
          .add(await into(db.preparationSchedules).insertReturning(
        step.toCompanion(false),
      ));
    }
    return preparationScheduleList;
  }

  Future<List<PreparationSchedule>> getPreparationSchedulesByScheduleId(
      String scheduleId) async {
    final List<PreparationSchedule> query =
        await (select(db.preparationSchedules)
              ..where((tbl) => tbl.scheduleId.equals(scheduleId)))
            .get();

    return query;
  }

  Future<void> deletePreparationScheduleByScheduleId(String scheduleId) async {
    await (delete(db.preparationSchedules)
          ..where((tbl) => tbl.scheduleId.equals(scheduleId)))
        .go();
  }
}
