import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/runtime_privacy_migration.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/preparation_snapshot_validation_test.dart'
    show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'all legacy runs migrate, orphans clear, unrelated settings survive',
    () async {
      final schedule = fixture();
      final prefs = await SharedPreferences.getInstance();
      final legacy = jsonEncode({
        'savedAt': DateTime.utc(2026, 9, 23, 9).millisecondsSinceEpoch,
        'startedAt': null,
        'scheduleFingerprint': schedule.legacyCacheFingerprint,
        'actionEvents': <Object>[],
        'steps': [
          {
            'id': 'step',
            'name': 'secret:|준비',
            'time': 300000,
            'nextId': null,
            'elapsed': 120000,
            'isDone': false,
          },
        ],
      });
      await prefs.setString('preparation_with_time_schedule', legacy);
      await prefs.setString('preparation_with_time_orphan', legacy);
      await prefs.setString('early_start_session_orphan', '{}');
      await prefs.setString('early_start_session_missing', '{}');
      await prefs.setString('unrelated', 'keep');
      var platformCalls = 0;
      final migration = RuntimePrivacyMigration(
        _Schedules(schedule),
        _Preparations(schedule),
        PreparationWithTimeLocalDataSourceImpl(),
        AlarmRegistryLocalDataSourceImpl(),
        cleanPlatform: () async {
          platformCalls++;
        },
      );
      await migration.run();
      final value = prefs.getString('preparation_with_time_schedule')!;
      expect(value, isNot(contains('secret')));
      expect(jsonDecode(value)['steps'][0]['elapsed'], 120000);
      expect(prefs.containsKey('preparation_with_time_orphan'), isFalse);
      expect(prefs.containsKey('early_start_session_orphan'), isFalse);
      expect(prefs.containsKey('early_start_session_missing'), isFalse);
      expect(prefs.getString('unrelated'), 'keep');
      await migration.run();
      expect(prefs.getString('preparation_with_time_schedule'), value);
      expect(platformCalls, 2);
    },
  );
  test(
    'platform cleanup failure is visible and retryable, without raw content',
    () async {
      final schedule = fixture();
      var attempts = 0;
      final migration = RuntimePrivacyMigration(
        _Schedules(schedule),
        _Preparations(schedule),
        PreparationWithTimeLocalDataSourceImpl(),
        AlarmRegistryLocalDataSourceImpl(),
        cleanPlatform: () async {
          if (++attempts == 1) throw StateError('platform unavailable');
        },
      );
      await expectLater(migration.run(), throwsStateError);
      await migration.run();
      expect(attempts, 2);
    },
  );
  test(
    'DB-unavailable cleanup removes legacy raw and does not touch unrelated data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preparation_with_time_old', 'secret corrupt');
      await prefs.setString('early_start_session_old', '{}');
      await prefs.setString('durable-key-sentinel', 'preserve');
      var cleanupCalled = false;
      await RuntimePrivacyMigration.clearLegacyWithoutDatabase(
        cleanupPlatform: () async {
          cleanupCalled = true;
        },
      );
      expect(cleanupCalled, isTrue);
      expect(prefs.containsKey('preparation_with_time_old'), isFalse);
      expect(prefs.containsKey('early_start_session_old'), isFalse);
      expect(prefs.getString('durable-key-sentinel'), 'preserve');
    },
  );
}

class _Schedules implements ScheduleRepository {
  _Schedules(this.schedule);
  final ScheduleWithPreparationEntity schedule;
  @override
  Future<ScheduleEntity> getScheduleById(String id) async {
    if (id != schedule.id) throw StateError('No element');
    return schedule;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preparations implements PreparationLocalDataSource {
  _Preparations(this.schedule);
  final ScheduleWithPreparationEntity schedule;
  @override
  Future<PreparationEntity> getPreparationByScheduleId(String id) async =>
      PreparationEntity(
        preparationStepList: schedule.preparation.preparationStepList,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
