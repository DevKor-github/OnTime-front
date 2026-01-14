import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class CreateCustomPreparationUseCase {
  final PreparationRepository _preparationRepository;

  CreateCustomPreparationUseCase(this._preparationRepository);

  Future<Result<Unit, Failure>> call(
      PreparationEntity preparationEntity, String scheduleId) async {
    return _preparationRepository.createCustomPreparation(
      preparationEntity,
      scheduleId,
    );
  }
}
