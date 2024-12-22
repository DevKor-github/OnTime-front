import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

class CreateDefaultPreparationUseCase {
  final PreparationRepository _preparationRepository;

  CreateDefaultPreparationUseCase(this._preparationRepository);

  Future<void> call(PreparationEntity preparationEntity) async {
    await _preparationRepository.createDefaultPreparation(preparationEntity);
  }
}
