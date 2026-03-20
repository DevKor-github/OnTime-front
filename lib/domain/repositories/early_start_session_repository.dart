import 'package:on_time_front/domain/entities/early_start_session_entity.dart';

abstract interface class EarlyStartSessionRepository {
  Future<void> markStarted({
    required String scheduleId,
    required DateTime startedAt,
  });

  Future<EarlyStartSessionEntity?> getSession(String scheduleId);

  Future<void> clear(String scheduleId);
}
