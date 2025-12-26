import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class UpdateDefaultPreparationUseCase {
  final PreparationRepository _preparationRepository;

  UpdateDefaultPreparationUseCase(this._preparationRepository);

  Future<Result<Unit, Failure>> call(PreparationEntity preparationEntity) async {
    return _preparationRepository.updateDefaultPreparation(preparationEntity);
  }
}
