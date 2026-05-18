import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/models/preparation_template_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';

abstract interface class PreparationTemplateRemoteDataSource {
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

@Injectable(as: PreparationTemplateRemoteDataSource)
class PreparationTemplateRemoteDataSourceImpl
    implements PreparationTemplateRemoteDataSource {
  final Dio dio;

  PreparationTemplateRemoteDataSourceImpl(this.dio);

  @override
  Future<List<PreparationTemplateEntity>> getPreparationTemplates() async {
    final result = await dio.get(Endpoint.preparationTemplates);
    if (result.statusCode == 200) {
      return (result.data['data'] as List<dynamic>)
          .map(
            (item) => PreparationTemplateModel.fromJson(
              item as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList();
    }
    throw Exception('Error getting preparation templates');
  }

  @override
  Future<PreparationTemplateEntity> getPreparationTemplate(
    String templateId,
  ) async {
    final result = await dio.get(Endpoint.preparationTemplateById(templateId));
    if (result.statusCode == 200) {
      return PreparationTemplateModel.fromJson(
        result.data['data'] as Map<String, dynamic>,
      ).toEntity();
    }
    throw Exception('Error getting preparation template');
  }

  @override
  Future<void> createPreparationTemplate({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) async {
    final request = UpsertPreparationTemplateRequestModel.fromValues(
      templateId: templateId,
      templateName: templateName,
      preparation: preparation,
    );
    final result = await dio.post(
      Endpoint.preparationTemplates,
      data: request.toJson(),
    );
    if (result.statusCode != 200) {
      throw Exception('Error creating preparation template');
    }
  }

  @override
  Future<void> updatePreparationTemplate({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) async {
    final request = UpsertPreparationTemplateRequestModel.fromValues(
      templateId: templateId,
      templateName: templateName,
      preparation: preparation,
    );
    final result = await dio.put(
      Endpoint.preparationTemplateById(templateId),
      data: request.toJson(),
    );
    if (result.statusCode != 200) {
      throw Exception('Error updating preparation template');
    }
  }

  @override
  Future<void> deletePreparationTemplate(String templateId) async {
    final result = await dio.delete(
      Endpoint.preparationTemplateById(templateId),
    );
    if (result.statusCode != 200) {
      throw Exception('Error deleting preparation template');
    }
  }
}
