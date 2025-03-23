import 'package:drift/drift.dart';
import 'package:on_time_front/core/utils/json_converters/duration_json_converters.dart';
import 'package:on_time_front/data/tables/places_table.dart';
import 'package:uuid/uuid.dart';

class Schedules extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  TextColumn get placeId => text().references(Places, #id)();
  TextColumn get scheduleName => text()();
  DateTimeColumn get scheduleTime => dateTime()();
  IntColumn get moveTime => integer().map(DurationSqlConverter())();
  BoolColumn get isChanged => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarted => boolean().withDefault(const Constant(false))();
  IntColumn get scheduleSpareTime =>
      integer().nullable().map(DurationSqlConverter())();
  TextColumn get scheduleNote => text().nullable()();
  IntColumn get latenessTime => integer().withDefault(const Constant(-1))();

  @override
  Set<Column> get primaryKey => {id};
}
