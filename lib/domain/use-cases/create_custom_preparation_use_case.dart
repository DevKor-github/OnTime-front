import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class CreateCustomPreparationUseCase {
  final PreparationRepository _preparationRepository;

  CreateCustomPreparationUseCase(this._preparationRepository);

  Future<void> call(
      PreparationEntity preparationEntity, String scheduleId) async {
    await _preparationRepository.createCustomPreparation(
        preparationEntity, scheduleId);
  }
}
