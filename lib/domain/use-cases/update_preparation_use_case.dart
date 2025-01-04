import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

class UpdatePreparationUseCase {
  final PreparationRepository _preparationRepository;

  UpdatePreparationUseCase(this._preparationRepository);

  Future<void> call(PreparationStepEntity preparationStepEntity) async {
    await _preparationRepository.updatePreparation(preparationStepEntity);
  }
}
