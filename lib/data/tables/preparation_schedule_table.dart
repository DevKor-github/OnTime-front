import 'package:drift/drift.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';

class PreparationSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scheduleId => integer().references(Schedules, #id)();
  TextColumn get preparationName => text().withLength(min: 1, max: 30)();
  IntColumn get preparationTime => integer()();
  IntColumn get order => integer()();
}
