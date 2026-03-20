import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

@Injectable()
class ClearTimedPreparationUseCase {
  const ClearTimedPreparationUseCase(this._timedPreparationRepository);

  final TimedPreparationRepository _timedPreparationRepository;

  Future<void> call(String scheduleId) {
    return _timedPreparationRepository.clearTimedPreparation(scheduleId);
  }
}
