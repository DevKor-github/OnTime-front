import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class GetDefaultPreparationUseCase {
  final PreparationRepository _preparationRepository;

  GetDefaultPreparationUseCase(this._preparationRepository);

  Future<PreparationEntity> call() async {
    return await _preparationRepository.getDefualtPreparation();
  }
}
