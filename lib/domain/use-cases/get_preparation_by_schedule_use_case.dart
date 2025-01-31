import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

class GetPreparationByScheduleIdUseCase {
  final PreparationRepository _preparationRepository;

  GetPreparationByScheduleIdUseCase(this._preparationRepository);

  Future<PreparationEntity> call(String scheduleId) async {
    return await _preparationRepository.getPreparationByScheduleId(scheduleId);
  }
}
