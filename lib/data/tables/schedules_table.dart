import 'package:drift/drift.dart';
import 'package:on_time_front/data/tables/places_table.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:uuid/uuid.dart';

class Schedules extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get placeId => text().references(Places, #id)();
  TextColumn get scheduleName => text()();
  DateTimeColumn get scheduleTime => dateTime()();
  DateTimeColumn get moveTime => dateTime()();
  BoolColumn get isChanged => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get scheduleSpareTime => dateTime()();
  TextColumn get scheduleNote => text()();

  @override
  Set<Column> get primaryKey => {id};
}
