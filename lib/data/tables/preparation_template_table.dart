import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class PreparationTemplates extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();
  TextColumn get templateName => text().withLength(min: 1, max: 30)();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
