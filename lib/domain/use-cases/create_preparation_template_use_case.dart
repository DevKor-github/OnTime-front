import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_template_repository.dart';

@Injectable()
class CreatePreparationTemplateUseCase {
  final PreparationTemplateRepository _repository;

  CreatePreparationTemplateUseCase(this._repository);

  Future<void> call({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) {
    return _repository.createPreparationTemplate(
      templateId: templateId,
      templateName: templateName,
      preparation: preparation,
    );
  }
}
