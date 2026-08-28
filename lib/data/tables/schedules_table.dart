import 'package:drift/drift.dart';
import 'package:on_time_front/core/utils/json_converters/duration_json_converters.dart';
import 'package:on_time_front/data/tables/places_table.dart';
import 'package:uuid/uuid.dart';

@TableIndex(name: 'schedules_schedule_time_idx', columns: {#scheduleTime})
@TableIndex(name: 'schedules_place_id_idx', columns: {#placeId})
class Schedules extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  TextColumn get placeId => text().references(Places, #id)();
  TextColumn get scheduleName => text()();
  TextColumn get timeZoneId => text().withDefault(const Constant('UTC'))();
  IntColumn get occurrenceOffsetSeconds => integer().nullable()();
  TextColumn get scheduleTime =>
      text().map(const CivilDateTimeSqlConverter())();
  IntColumn get moveTime => integer().map(DurationSqlConverter())();
  BoolColumn get isChanged => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarted => boolean().withDefault(const Constant(false))();
  IntColumn get scheduleSpareTime =>
      integer().nullable().map(DurationSqlConverter())();
  TextColumn get scheduleNote => text().nullable()();
  IntColumn get latenessTime => integer().withDefault(const Constant(-1))();
  TextColumn get doneStatus => text().withDefault(const Constant('notEnded'))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get preparationMode => text().nullable()();
  TextColumn get preparationTemplateId => text().nullable()();
  TextColumn get preparationTemplateName => text().nullable()();
  BoolColumn get preparationTemplateDeleted =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get preparationFrozen =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get scoreContributionRecorded =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
