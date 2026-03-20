import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/data_sources/early_start_session_local_data_source.dart';
import 'package:on_time_front/domain/entities/early_start_session_entity.dart';
import 'package:on_time_front/domain/repositories/early_start_session_repository.dart';

@Singleton(as: EarlyStartSessionRepository)
class EarlyStartSessionRepositoryImpl implements EarlyStartSessionRepository {
  EarlyStartSessionRepositoryImpl({required this.localDataSource});

  final EarlyStartSessionLocalDataSource localDataSource;

  @override
  Future<void> markStarted({
    required String scheduleId,
    required DateTime startedAt,
  }) {
    return localDataSource.saveSession(
      scheduleId: scheduleId,
      startedAt: startedAt,
    );
  }

  @override
  Future<EarlyStartSessionEntity?> getSession(String scheduleId) async {
    final startedAt = await localDataSource.loadSessionStartedAt(scheduleId);
    if (startedAt == null) return null;
    return EarlyStartSessionEntity(
        scheduleId: scheduleId, startedAt: startedAt);
  }

  @override
  Future<void> clear(String scheduleId) {
    return localDataSource.clearSession(scheduleId);
  }
}
