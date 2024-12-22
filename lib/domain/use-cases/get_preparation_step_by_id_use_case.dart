import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

class GetPreparationStepByIdUseCase {
  final PreparationRepository _preparationRepository;

  GetPreparationStepByIdUseCase(this._preparationRepository);

  Stream<PreparationStepEntity> call(String preparationStepId) {
    return _preparationRepository.getPreparationStepById(preparationStepId);
  }
}
