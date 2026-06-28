import 'package:drift/drift.dart';
import 'package:on_time_front/data/tables/user_table.dart';
import 'package:uuid/uuid.dart';

@TableIndex(name: 'preparation_users_user_id_idx', columns: {#userId})
@TableIndex(
  name: 'preparation_users_next_preparation_id_idx',
  columns: {#nextPreparationId},
)
class PreparationUsers extends Table {
  TextColumn get id => text().clientDefault(() => Uuid().v7())();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get preparationName => text().withLength(min: 1, max: 30)();
  IntColumn get preparationTime => integer()();
  TextColumn get nextPreparationId =>
      text().nullable().references(PreparationUsers, #id)();

  @override
  Set<Column> get primaryKey => {id};
}
