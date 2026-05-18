import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/early_start_session_local_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late EarlyStartSessionLocalDataSourceImpl dataSource;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dataSource = EarlyStartSessionLocalDataSourceImpl();
  });

  test('saves and loads the early start timestamp per schedule', () async {
    final startedAt = DateTime(2026, 5, 15, 8, 30);

    await dataSource.saveSession(
      scheduleId: 'schedule-1',
      startedAt: startedAt,
    );

    expect(
      await dataSource.loadSessionStartedAt('schedule-1'),
      DateTime.fromMillisecondsSinceEpoch(startedAt.millisecondsSinceEpoch),
    );
    expect(await dataSource.loadSessionStartedAt('schedule-2'), isNull);
  });

  test(
    'returns null for missing, corrupt, and incomplete session payloads',
    () async {
      SharedPreferences.setMockInitialValues({
        'early_start_session_corrupt': 'not json',
        'early_start_session_incomplete': '{}',
      });
      final source = EarlyStartSessionLocalDataSourceImpl();

      expect(await source.loadSessionStartedAt('missing'), isNull);
      expect(await source.loadSessionStartedAt('corrupt'), isNull);
      expect(await source.loadSessionStartedAt('incomplete'), isNull);
    },
  );

  test('clearSession removes only the requested schedule session', () async {
    final startedAt = DateTime(2026, 5, 15, 8, 30);
    await dataSource.saveSession(scheduleId: 'a', startedAt: startedAt);
    await dataSource.saveSession(scheduleId: 'b', startedAt: startedAt);

    await dataSource.clearSession('a');

    expect(await dataSource.loadSessionStartedAt('a'), isNull);
    expect(await dataSource.loadSessionStartedAt('b'), isNotNull);
  });
}
