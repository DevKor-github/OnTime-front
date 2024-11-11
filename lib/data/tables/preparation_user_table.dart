import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class PreparationUsers extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  TextColumn get userId => text()();
  TextColumn get preparationName => text().withLength(min: 1, max: 30)();
  IntColumn get preparationTime => integer()();
  IntColumn get order => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
