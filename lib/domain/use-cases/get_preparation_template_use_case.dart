import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_template_repository.dart';

@Injectable()
class GetPreparationTemplateUseCase {
  final PreparationTemplateRepository _repository;

  GetPreparationTemplateUseCase(this._repository);

  Future<PreparationTemplateEntity> call(String templateId) {
    return _repository.getPreparationTemplate(templateId);
  }
}
