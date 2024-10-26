import 'package:drift/drift.dart';
import 'package:on_time_front/data/tables/places_table.dart';

class Schedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get placeId => integer().references(Places, #id)();
  TextColumn get scheduleName => text()();
  DateTimeColumn get scheduleTime => dateTime()();
  DateTimeColumn get moveTime => dateTime()();
  BoolColumn get isChanged => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get scheduleSpareTime => dateTime()();
  TextColumn get scheduleNote => text()();
}
