import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/data/repositories/schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_start_rejected.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  late Directory directory;
  late AppDatabase database;
  late ScheduleRepositoryImpl repository;
  late DateTime now;
  late Map<String, tz.Location> originalRules;
  late tz.Location originalLocal;

  Future<void> open() async {
    database = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/app.sqlite')),
    );
    repository = ScheduleRepositoryImpl(
      database: database,
      timedPreparationRepository: _UnusedRuntime(),
      now: () => now,
    );
  }

  setUp(() async {
    TimeZoneRules.ensureInitialized();
    originalRules = Map.of(tz.timeZoneDatabase.locations);
    originalLocal = tz.local;
    now = DateTime.utc(2026, 9, 24);
    directory = await Directory.systemTemp.createTemp('ontime-a10-start-');
    await open();
    await database.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await database.close();
    await directory.delete(recursive: true);
    tz.timeZoneDatabase.locations
      ..clear()
      ..addAll(originalRules);
    tz.setLocalLocation(originalLocal);
  });

  ScheduleEntity schedule({
    String id = 'appointment',
    DateTime? civil,
    String zone = 'Asia/Seoul',
    int? offset,
  }) => ScheduleEntity(
    id: id,
    place: PlaceEntity(id: 'place-$id', placeName: 'Office'),
    scheduleName: 'Appointment',
    scheduleTime: civil ?? DateTime.utc(2026, 9, 25, 9, 0, 4, 123, 456),
    timeZoneId: zone,
    occurrenceOffsetSeconds: offset,
    moveTime: Duration.zero,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration.zero,
    scheduleNote: 'Retain the original civil fields',
  );

  Future<Map<String, Object?>> row([String id = 'appointment']) async =>
      (await database.customSelect('SELECT * FROM schedules').get())
          .singleWhere((value) => value.read<String>('id') == id)
          .data;

  Future<Map<String, Object?>> profile() async =>
      (await database.customSelect('SELECT * FROM users').getSingle()).data;

  ScheduleWithPreparationEntity runtime(ScheduleEntity value) =>
      ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
        value,
        const PreparationWithTimeEntity(preparationStepList: []),
        timeResolution: ScheduleTimeResolver.resolve(
          value,
          nowUtc: now.toUtc(),
        ),
      );

  test(
    'only first start records the rule-derived offset with facts and one revision',
    () async {
      await repository.createSchedule(schedule());
      final before = await row();
      final beforeProfile = await profile();
      final raw = await repository.getScheduleById('appointment');
      final interpreted = runtime(raw);
      final fingerprint = interpreted.cacheFingerprint;
      expect(
        interpreted.occurrenceInstantUtc,
        DateTime.utc(2026, 9, 25, 0, 0, 4, 123, 456),
      );
      expect(raw.occurrenceOffsetSeconds, isNull);
      expect(
        await row(),
        before,
        reason: 'Read and interpretation cannot backfill the offset',
      );
      expect(await profile(), beforeProfile);

      final firstStart = now.add(const Duration(seconds: 7));
      expect(
        await repository.startSchedule('appointment', startedAt: firstStart),
        firstStart,
      );
      final after = await row();
      final started = await repository.getScheduleById('appointment');
      expect(started.occurrenceOffsetSeconds, 32400);
      expect(started.startedAt!.toUtc(), firstStart);
      expect(started.isStarted, isTrue);
      expect(started.preparationFrozen, isTrue);
      expect(after['schedule_time'], before['schedule_time']);
      expect(after['aggregate_incarnation'], before['aggregate_incarnation']);
      expect(
        after['aggregate_version'],
        (before['aggregate_version'] as int) + 1,
      );
      expect(
        (await profile())['data_revision'],
        (beforeProfile['data_revision'] as int) + 1,
      );
      expect(runtime(started).cacheFingerprint, fingerprint);
    },
  );

  test(
    'revision failure rolls back offset, facts, aggregate authority and all profile markers',
    () async {
      await repository.createSchedule(schedule());
      final before = await row();
      final beforeProfile = await profile();
      await database.customStatement(
        "CREATE TRIGGER reject_a10_revision BEFORE UPDATE OF data_revision ON users BEGIN SELECT RAISE(ABORT, 'a10 injected revision failure'); END",
      );
      await expectLater(
        repository.startSchedule('appointment', startedAt: now),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('a10 injected revision failure'),
          ),
        ),
      );
      expect(await row(), before);
      expect(await profile(), beforeProfile);
      await database.customStatement('DROP TRIGGER reject_a10_revision');

      final first = await repository.startSchedule(
        'appointment',
        startedAt: now,
      );
      final committed = await row();
      final committedProfile = await profile();
      now = now.add(const Duration(minutes: 5));
      expect(
        await repository.startSchedule('appointment', startedAt: now),
        first,
      );
      expect(await row(), committed);
      expect(await profile(), committedProfile);
      expect(committed['occurrence_offset_seconds'], 32400);
      expect(
        committedProfile['data_revision'],
        (beforeProfile['data_revision'] as int) + 1,
      );
    },
  );

  test(
    'concurrent and repeated starts retain one offset and first start receipt',
    () async {
      await repository.createSchedule(schedule());
      final before = await row();
      final beforeProfile = await profile();
      final requested = [now, now.add(const Duration(seconds: 1))];
      final results = await Future.wait([
        for (final stamp in requested)
          repository.startSchedule('appointment', startedAt: stamp),
      ]);
      expect(results[0], results[1]);
      expect(requested, contains(results.first));
      final committed = await row();
      final committedProfile = await profile();
      expect(committed['occurrence_offset_seconds'], 32400);
      expect(
        committed['aggregate_version'],
        (before['aggregate_version'] as int) + 1,
      );
      expect(
        committedProfile['data_revision'],
        (beforeProfile['data_revision'] as int) + 1,
      );
      expect(
        await repository.startSchedule(
          'appointment',
          startedAt: now.add(const Duration(hours: 1)),
        ),
        results.first,
      );
      expect(await row(), committed);
      expect(await profile(), committedProfile);
    },
  );

  test(
    'an explicitly selected past occurrence still permits an otherwise valid manual late start',
    () async {
      await repository.createSchedule(
        schedule(civil: DateTime.utc(2026, 9, 23, 9), offset: 32400),
      );
      expect(
        await repository.startSchedule('appointment', startedAt: now),
        now,
      );
      final started = await repository.getScheduleById('appointment');
      expect(started.occurrenceOffsetSeconds, 32400);
      expect(started.occurrenceInstantUtc, DateTime.utc(2026, 9, 23));
      expect(started.isStarted, isTrue);
    },
  );

  for (final kind in [
    'past-null',
    'overlap-null',
    'gap',
    'unknown-zone',
    'stale-offset',
    'restored-protected-null',
  ]) {
    test('$kind cannot acquire new start facts or a guessed offset', () async {
      now = DateTime.utc(2026, 1, 1);
      final value = switch (kind) {
        'past-null' => schedule(civil: DateTime.utc(2025, 12, 31, 9)),
        'overlap-null' => schedule(
          civil: DateTime.utc(2026, 11, 1, 1, 30),
          zone: 'America/New_York',
        ),
        'gap' => schedule(
          civil: DateTime.utc(2026, 3, 8, 2, 30),
          zone: 'America/New_York',
        ),
        'unknown-zone' => schedule(zone: 'Not/A_Real_Zone'),
        'stale-offset' => schedule(offset: 36000),
        'restored-protected-null' => schedule().copyWith(
          startedAt: DateTime.utc(2025),
          preparationFrozen: true,
        ),
        _ => throw StateError('Unknown test case'),
      };
      // The existing repository writer seeds an admitted legacy row; this test
      // exercises start admission, not new-form save validation or a restore.
      await repository.createSchedule(value);
      final before = await row();
      final beforeProfile = await profile();
      await expectLater(
        repository.startSchedule('appointment', startedAt: now),
        throwsA(isA<ScheduleStartRejected>()),
      );
      expect(await row(), before);
      expect(await profile(), beforeProfile);
    });
  }

  test(
    'an already active protected null row is not silently repaired by an idempotent retry',
    () async {
      final originalStart = DateTime.utc(2026, 9, 23);
      await repository.createSchedule(
        schedule().copyWith(
          isStarted: true,
          startedAt: originalStart,
          preparationFrozen: true,
        ),
      );
      final before = await row();
      final beforeProfile = await profile();
      expect(
        await repository.startSchedule('appointment', startedAt: now),
        originalStart,
      );
      expect(await row(), before);
      expect(await profile(), beforeProfile);
      expect(
        (await repository.getScheduleById(
          'appointment',
        )).occurrenceOffsetSeconds,
        isNull,
      );
    },
  );

  test(
    'the captured target survives file-database reopen, deadline and loaded rule changes',
    () async {
      const zone = 'Test/A10_Start_Target';
      tz.Location fixedRule(int offset) => tz.Location(zone, [], [], [
        tz.TimeZone(offset, isDst: false, abbreviation: 'A10'),
      ]);
      tz.timeZoneDatabase.locations[zone] = fixedRule(32400000);
      await repository.createSchedule(schedule(zone: zone));
      final prior = runtime(await repository.getScheduleById('appointment'));
      final instant = prior.occurrenceInstantUtc;
      final fingerprint = prior.cacheFingerprint;
      final first = await repository.startSchedule(
        'appointment',
        startedAt: now,
      );
      final committed = await row();
      final committedProfile = await profile();

      await repository.dispose();
      await database.close();
      now = DateTime.utc(2026, 10, 1);
      tz.timeZoneDatabase.locations[zone] = fixedRule(36000000);
      // This changes the timezone library's display location; actual OS timezone
      // behavior is covered separately by the explicit process TZ matrix.
      tz.setLocalLocation(TimeZoneRules.location('America/New_York'));
      await open();
      final reopened = await repository.getScheduleById('appointment');
      final resolution = ScheduleTimeResolver.resolve(reopened, nowUtc: now);
      expect(resolution.isHistorical, isTrue);
      expect(resolution.instantUtc, instant);
      expect(runtime(reopened).cacheFingerprint, fingerprint);
      expect(
        await repository.startSchedule('appointment', startedAt: now),
        first,
      );
      expect(await row(), committed);
      expect(await profile(), committedProfile);
    },
  );
}

/// Starting the durable schedule is independent of runtime projection storage.
class _UnusedRuntime implements TimedPreparationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected runtime projection access: ${invocation.memberName}',
  );
}
