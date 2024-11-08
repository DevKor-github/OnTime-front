import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Users extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  TextColumn get email => text().withLength(min: 1, max: 320)();
  TextColumn get password => text().withLength(min: 1, max: 30)();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get spareTime => integer()();
  TextColumn get note => text()();
  RealColumn get score => real()();

  @override
  Set<Column> get primaryKey => {id};
}
