import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

class GetPreparationByScheduleIdUseCase {
  final PreparationRepository _preparationRepository;

  GetPreparationByScheduleIdUseCase(this._preparationRepository);

  Stream<PreparationEntity> call(String scheduleId) {
    return _preparationRepository.getPreparationByScheduleId(scheduleId);
  }
}
