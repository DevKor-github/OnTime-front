import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class LoadPreparationByScheduleIdUseCase {
  final PreparationRepository _preparationRepository;

  LoadPreparationByScheduleIdUseCase(this._preparationRepository);

  /// Loads preparation for the given schedule ID.
  /// This refreshes the repository stream from encrypted local storage.
  ///
  /// [scheduleId] - The ID of the schedule to load preparation for
  Future<void> call(String scheduleId) async {
    await _preparationRepository.getPreparationByScheduleId(scheduleId);
  }
}
