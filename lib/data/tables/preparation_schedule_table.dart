import 'package:drift/drift.dart';
import 'package:on_time_front/data/tables/schedules_table.dart';
import 'package:uuid/uuid.dart';

class PreparationSchedules extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  TextColumn get scheduleId => text().references(Schedules, #id)();
  TextColumn get preparationName => text().withLength(min: 1, max: 30)();
  IntColumn get preparationTime => integer()();
  IntColumn get order => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
