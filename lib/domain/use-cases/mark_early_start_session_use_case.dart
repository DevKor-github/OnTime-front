import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';

@Injectable()
class MarkEarlyStartSessionUseCase {
  const MarkEarlyStartSessionUseCase(this._earlyStartSessionRepository);

  final EarlyStartSessionRepository _earlyStartSessionRepository;

  Future<void> call({
    required String scheduleId,
    required DateTime startedAt,
  }) {
    return _earlyStartSessionRepository.markStarted(
      scheduleId: scheduleId,
      startedAt: startedAt,
    );
  }
}
