import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';

@Injectable()
class GetEarlyStartSessionUseCase {
  const GetEarlyStartSessionUseCase(this._earlyStartSessionRepository);

  final EarlyStartSessionRepository _earlyStartSessionRepository;

  Future<EarlyStartSessionEntity?> call(String scheduleId) {
    return _earlyStartSessionRepository.getSession(scheduleId);
  }
}
