import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

class DeletePreparationUseCase {
  final PreparationRepository _preparationRepository;

  DeletePreparationUseCase(this._preparationRepository);

  Future<PreparationEntity> call(PreparationEntity preparationEntity) async {
    return await _preparationRepository.deletePreparation(preparationEntity);
  }
}
