import 'package:drift/drift.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text().withLength(min: 1, max: 320)();
  TextColumn get password => text().withLength(min: 1, max: 30)();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  IntColumn get spareTime => integer()();
  TextColumn get note => text()();
  RealColumn get score => real()();
}
