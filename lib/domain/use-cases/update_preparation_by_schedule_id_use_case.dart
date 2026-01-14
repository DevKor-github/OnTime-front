import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class UpdatePreparationByScheduleIdUseCase {
  final PreparationRepository _preparationRepository;

  UpdatePreparationByScheduleIdUseCase(this._preparationRepository);

  Future<Result<Unit, Failure>> call(
      PreparationEntity preparationEntity, String scheduleId) async {
    return _preparationRepository.updatePreparationByScheduleId(
      preparationEntity,
      scheduleId,
    );
  }
}
