import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

@Injectable()
class SaveTimedPreparationUseCase {
  final TimedPreparationRepository _timedPreparationRepository;

  SaveTimedPreparationUseCase(this._timedPreparationRepository);

  Future<void> call(String scheduleId, PreparationWithTimeEntity preparation) {
    return _timedPreparationRepository.saveTimedPreparation(
        scheduleId, preparation);
  }
}
