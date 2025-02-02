import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class UpdateDefaultPreparationUseCase {
  final PreparationRepository _preparationRepository;

  UpdateDefaultPreparationUseCase(this._preparationRepository);

  Future<void> call(PreparationEntity preparationEntity) async {
    await _preparationRepository.updateDefaultPreparation(preparationEntity);
  }
}
