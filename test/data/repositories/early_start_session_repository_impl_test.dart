import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/early_start_session_local_data_source.dart';
import 'package:on_time_front/data/repositories/early_start_session_repository_impl.dart';

void main() {
  test(
    'markStarted saves and getSession restores early-start timestamp',
    () async {
      final localDataSource = _FakeEarlyStartSessionLocalDataSource();
      final repository = EarlyStartSessionRepositoryImpl(
        localDataSource: localDataSource,
      );
      final startedAt = DateTime.utc(2026, 5, 15, 8);

      await repository.markStarted(
        scheduleId: 'schedule-1',
        startedAt: startedAt,
      );

      final session = await repository.getSession('schedule-1');
      expect(session?.scheduleId, 'schedule-1');
      expect(session?.startedAt, startedAt);
    },
  );

  test('getSession returns null and clear removes saved session', () async {
    final localDataSource = _FakeEarlyStartSessionLocalDataSource();
    final repository = EarlyStartSessionRepositoryImpl(
      localDataSource: localDataSource,
    );
    final startedAt = DateTime.utc(2026, 5, 15, 8);

    expect(await repository.getSession('missing'), isNull);

    await repository.markStarted(
      scheduleId: 'schedule-1',
      startedAt: startedAt,
    );
    await repository.clear('schedule-1');

    expect(await repository.getSession('schedule-1'), isNull);
  });
}

class _FakeEarlyStartSessionLocalDataSource
    implements EarlyStartSessionLocalDataSource {
  final sessions = <String, DateTime>{};

  @override
  Future<void> saveSession({
    required String scheduleId,
    required DateTime startedAt,
  }) async {
    sessions[scheduleId] = startedAt;
  }

  @override
  Future<DateTime?> loadSessionStartedAt(String scheduleId) async {
    return sessions[scheduleId];
  }

  @override
  Future<void> clearSession(String scheduleId) async {
    sessions.remove(scheduleId);
  }
}
