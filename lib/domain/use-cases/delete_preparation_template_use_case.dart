import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/preparation_template_repository.dart';

@Injectable()
class DeletePreparationTemplateUseCase {
  final PreparationTemplateRepository _repository;

  DeletePreparationTemplateUseCase(this._repository);

  Future<void> call(String templateId) {
    return _repository.deletePreparationTemplate(templateId);
  }
}
