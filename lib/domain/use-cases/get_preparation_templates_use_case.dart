import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_template_repository.dart';

@Injectable()
class GetPreparationTemplatesUseCase {
  final PreparationTemplateRepository _repository;

  GetPreparationTemplatesUseCase(this._repository);

  Future<List<PreparationTemplateEntity>> call() {
    return _repository.getPreparationTemplates();
  }
}
