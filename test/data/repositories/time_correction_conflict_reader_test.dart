import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/time_correction_conflict_reader.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2030, 1, 1);
  ScheduleEntity row(String id, {String zone = 'UTC', bool past = false}) =>
      ScheduleEntity(
        id: id,
        place: PlaceEntity(id: 'place-$id', placeName: 'Office'),
        scheduleName: id,
        scheduleTime: past ? DateTime.utc(2020) : DateTime.utc(2030, 1, 2, 10),
        timeZoneId: zone,
        occurrenceOffsetSeconds: zone == 'UTC' ? 0 : null,
        moveTime: Duration.zero,
        scheduleSpareTime: Duration.zero,
        scheduleNote: '',
        isChanged: false,
        isStarted: false,
      );
  Future<TimeCorrectionConflictWorld> read() => readTimeCorrectionConflictWorld(
    db: db,
    nowUtc: now,
    budget: BackupBudget(),
  );
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
  });
  tearDown(() => db.close());

  test(
    'step overflow is rejected at the bounded SQL reader before proof admission',
    () async {
      await db.customStatement(
        "INSERT INTO preparation_definitions(id,owner_id,scope,name,created_at) VALUES('def','a','occurrence','Owned',1)",
      );
      await db.transaction(() async {
        for (var i = 0; i <= BackupLimits.preparationSteps; i++) {
          await db.customStatement(
            'INSERT INTO preparation_definition_steps(id,definition_id,name,minutes,position) VALUES(?,?,?,?,?)',
            ['step-$i', 'def', 'Ready', 1, i],
          );
        }
      });
      await db.scheduleDao.createSchedule(
        row(
          'a',
        ).copyWith(preparationDefinitionId: 'def').toScheduleWithPlaceRow(),
      );
      await expectLater(read(), throwsA(isA<BackupProcessingFailure>()));
    },
  );
  test(
    'a frozen empty captured preparation does not gain mutable default minutes',
    () async {
      await db.customStatement(
        "INSERT INTO preparation_users(id,user_id,preparation_name,preparation_time) VALUES('default','local-profile','Default',30)",
      );
      final frozen = row(
        'frozen',
      ).copyWith(isStarted: true, startedAt: now, preparationFrozen: true);
      await db.scheduleDao.createSchedule(frozen.toScheduleWithPlaceRow());
      await db.scheduleDao.createSchedule(
        row('normal').toScheduleWithPlaceRow(),
      );
      final world = await read();
      final actual = world.rows.singleWhere((e) => e.schedule.id == 'frozen');
      expect(actual.preparationStartUtc, actual.instantUtc);
      final normal = world.rows.singleWhere((e) => e.schedule.id == 'normal');
      expect(
        normal.instantUtc.difference(normal.preparationStartUtc),
        const Duration(minutes: 30),
      );
    },
  );
  test(
    'current template is used for an unfrozen row while frozen captured steps stay owned',
    () async {
      await db.customStatement(
        "INSERT INTO preparation_templates(id,template_name,created_at,updated_at) VALUES('template','Template',1,1)",
      );
      await db.customStatement(
        "INSERT INTO preparation_template_steps(id,template_id,preparation_name,preparation_time,position) VALUES('template-step','template','Changed',45,0)",
      );
      for (final id in ['normal', 'frozen']) {
        await db.scheduleDao.createSchedule(
          row(id)
              .copyWith(
                preparationMode: SchedulePreparationMode.template,
                preparationTemplateId: 'template',
                preparationTemplateName: 'Template',
                preparationFrozen: id == 'frozen',
                isStarted: id == 'frozen',
                startedAt: id == 'frozen' ? now : null,
              )
              .toScheduleWithPlaceRow(),
        );
        await db.customStatement(
          'INSERT INTO preparation_schedules(id,schedule_id,preparation_name,preparation_time) VALUES(?,?,?,?)',
          ['own-$id', id, 'Captured', 10],
        );
      }
      final world = await read();
      expect(
        world.rows
            .singleWhere((e) => e.schedule.id == 'normal')
            .instantUtc
            .difference(
              world.rows
                  .singleWhere((e) => e.schedule.id == 'normal')
                  .preparationStartUtc,
            ),
        const Duration(minutes: 45),
      );
      expect(
        world.rows
            .singleWhere((e) => e.schedule.id == 'frozen')
            .instantUtc
            .difference(
              world.rows
                  .singleWhere((e) => e.schedule.id == 'frozen')
                  .preparationStartUtc,
            ),
        const Duration(minutes: 10),
      );
    },
  );
  test(
    'future uncertainty remains separate from exact intervals and historical uncertainty',
    () async {
      await db.scheduleDao.createSchedule(
        row('normal').toScheduleWithPlaceRow(),
      );
      await db.scheduleDao.createSchedule(
        row('future', zone: 'Unknown/Retired').toScheduleWithPlaceRow(),
      );
      await db.scheduleDao.createSchedule(
        row(
          'past',
          zone: 'Unknown/Retired',
          past: true,
        ).toScheduleWithPlaceRow(),
      );
      await db.scheduleDao.createSchedule(
        row('completed', zone: 'Unknown/Retired')
            .copyWith(doneStatus: ScheduleDoneStatus.normalEnd, finishedAt: now)
            .toScheduleWithPlaceRow(),
      );
      final world = await read();
      expect(world.rows.map((e) => e.schedule.id), ['normal']);
      expect(world.unresolvedIds, {'future'});
      final possible = world.possibleOverlaps.single;
      expect(
        possible.mayOverlap(
          DateTime.utc(2030, 1, 2),
          DateTime.utc(2030, 1, 2, 12),
        ),
        isTrue,
      );
      expect(
        possible.mayOverlap(DateTime.utc(2031), DateTime.utc(2031, 1, 2)),
        isFalse,
      );
    },
  );
  test(
    'unknown active target keeps an open possible-impact range without fabricating an instant',
    () async {
      await db.scheduleDao.createSchedule(
        row('active', zone: 'Unknown/Retired', past: true)
            .copyWith(
              isStarted: true,
              startedAt: DateTime.utc(2020),
              preparationFrozen: true,
            )
            .toScheduleWithPlaceRow(),
      );
      final world = await read();
      expect(world.rows, isEmpty);
      expect(world.possibleOverlaps.single.latestTargetUtc, isNull);
      expect(
        world.possibleOverlaps.single.mayOverlap(
          now,
          now.add(const Duration(hours: 1)),
        ),
        isTrue,
      );
    },
  );
}
