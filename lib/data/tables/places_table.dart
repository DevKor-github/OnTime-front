import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Places extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  TextColumn get placeName => text().withLength(min: 1, max: 30)();

  @override
  Set<Column> get primaryKey => {id};
}
