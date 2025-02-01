import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class GetPreparationStepByIdUseCase {
  final PreparationRepository _preparationRepository;

  GetPreparationStepByIdUseCase(this._preparationRepository);

  Future<PreparationStepEntity> call(String preparationStepId) async {
    return await _preparationRepository
        .getPreparationStepById(preparationStepId);
  }
}
