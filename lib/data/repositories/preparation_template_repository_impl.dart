import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/preparation_template_remote_data_source.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_template_repository.dart';

@Singleton(as: PreparationTemplateRepository)
class PreparationTemplateRepositoryImpl
    implements PreparationTemplateRepository {
  final PreparationTemplateRemoteDataSource remoteDataSource;

  PreparationTemplateRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<PreparationTemplateEntity>> getPreparationTemplates() {
    return remoteDataSource.getPreparationTemplates();
  }

  @override
  Future<PreparationTemplateEntity> getPreparationTemplate(String templateId) {
    return remoteDataSource.getPreparationTemplate(templateId);
  }

  @override
  Future<void> createPreparationTemplate({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) {
    return remoteDataSource.createPreparationTemplate(
      templateId: templateId,
      templateName: templateName,
      preparation: preparation,
    );
  }

  @override
  Future<void> updatePreparationTemplate({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) {
    return remoteDataSource.updatePreparationTemplate(
      templateId: templateId,
      templateName: templateName,
      preparation: preparation,
    );
  }

  @override
  Future<void> deletePreparationTemplate(String templateId) {
    return remoteDataSource.deletePreparationTemplate(templateId);
  }
}
