import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_template_repository.dart';

@Injectable()
class UpdatePreparationTemplateUseCase {
  final PreparationTemplateRepository _repository;

  UpdatePreparationTemplateUseCase(this._repository);

  Future<void> call({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) {
    return _repository.updatePreparationTemplate(
      templateId: templateId,
      templateName: templateName,
      preparation: preparation,
    );
  }
}
