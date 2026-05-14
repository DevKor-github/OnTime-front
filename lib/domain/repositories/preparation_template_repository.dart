import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';

abstract interface class PreparationTemplateRepository {
  Future<List<PreparationTemplateEntity>> getPreparationTemplates();

  Future<PreparationTemplateEntity> getPreparationTemplate(String templateId);

  Future<void> createPreparationTemplate({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  });

  Future<void> updatePreparationTemplate({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  });

  Future<void> deletePreparationTemplate(String templateId);
}
