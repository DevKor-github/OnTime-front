import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';

@Injectable()
class ClearEarlyStartSessionUseCase {
  const ClearEarlyStartSessionUseCase(this._earlyStartSessionRepository);

  final EarlyStartSessionRepository _earlyStartSessionRepository;

  Future<void> call(String scheduleId) {
    return _earlyStartSessionRepository.clear(scheduleId);
  }
}
