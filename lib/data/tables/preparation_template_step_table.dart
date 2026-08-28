import 'package:drift/drift.dart';
import 'package:on_time_front/data/tables/preparation_template_table.dart';
import 'package:uuid/uuid.dart';

@TableIndex(
  name: 'preparation_template_steps_template_id_idx',
  columns: {#templateId},
)
class PreparationTemplateSteps extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();
  TextColumn get templateId => text().references(PreparationTemplates, #id)();
  TextColumn get preparationName => text().withLength(min: 1, max: 30)();
  IntColumn get preparationTime => integer()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
