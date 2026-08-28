import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Users extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  IntColumn get spareTime => integer()();
  TextColumn get note => text()();
  BoolColumn get isOnboardingCompleted =>
      boolean().withDefault(const Constant(false))();
  IntColumn get eligibleOutcomeCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get onTimeOutcomeCount =>
      integer().withDefault(const Constant(0))();
  BoolColumn get alarmsEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get alarmOffsetMinutes =>
      integer().withDefault(const Constant(0))();
  BoolColumn get detailedNotificationContent =>
      boolean().withDefault(const Constant(false))();
  IntColumn get dataRevision => integer().withDefault(const Constant(0))();
  IntColumn get lastExportedRevision => integer().nullable()();
  DateTimeColumn get lastExportedAt => dateTime().nullable()();
  DateTimeColumn get firstDurableDataAt => dateTime().nullable()();
  DateTimeColumn get lastDurableDataAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
