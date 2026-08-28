import 'package:drift/drift.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/tables/preparation_template_step_table.dart';
import 'package:on_time_front/data/tables/preparation_template_table.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';

part 'preparation_template_dao.g.dart';

@DriftAccessor(tables: [PreparationTemplates, PreparationTemplateSteps])
class PreparationTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$PreparationTemplateDaoMixin {
  PreparationTemplateDao(super.db);

  Future<List<PreparationTemplateEntity>> getAll() async {
    final templates = await (select(
      preparationTemplates,
    )..orderBy([(table) => OrderingTerm.asc(table.createdAt)])).get();
    return Future.wait(templates.map(_toEntity));
  }

  Future<PreparationTemplateEntity> getById(String id) async {
    final template = await (select(
      preparationTemplates,
    )..where((table) => table.id.equals(id))).getSingle();
    return _toEntity(template);
  }

  Future<void> put({
    required String id,
    required String name,
    required PreparationEntity preparation,
    required DateTime now,
  }) async {
    await transaction(() async {
      final existing = await (select(
        preparationTemplates,
      )..where((table) => table.id.equals(id))).getSingleOrNull();
      await into(preparationTemplates).insertOnConflictUpdate(
        PreparationTemplatesCompanion.insert(
          id: Value(id),
          templateName: name,
          createdAt: Value(existing?.createdAt ?? now),
          updatedAt: Value(now),
        ),
      );
      await (delete(
        preparationTemplateSteps,
      )..where((table) => table.templateId.equals(id))).go();
      for (final (position, step) in preparation.preparationStepList.indexed) {
        await into(preparationTemplateSteps).insert(
          PreparationTemplateStepsCompanion.insert(
            id: Value(step.id),
            templateId: id,
            preparationName: step.preparationName,
            preparationTime: step.preparationTime.inMinutes,
            position: position,
          ),
        );
      }
    });
  }

  Future<void> deleteById(String id) async {
    await (delete(
      preparationTemplates,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<PreparationTemplateEntity> _toEntity(PreparationTemplate row) async {
    final steps =
        await (select(preparationTemplateSteps)
              ..where((table) => table.templateId.equals(row.id))
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();
    return PreparationTemplateEntity(
      id: row.id,
      name: row.templateName,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      preparation: PreparationEntity(
        preparationStepList: [
          for (final (position, step) in steps.indexed)
            PreparationStepEntity(
              id: step.id,
              preparationName: step.preparationName,
              preparationTime: Duration(minutes: step.preparationTime),
              nextPreparationId: position + 1 < steps.length
                  ? steps[position + 1].id
                  : null,
            ),
        ],
      ),
    );
  }
}
