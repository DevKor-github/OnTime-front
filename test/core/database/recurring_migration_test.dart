import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  test(
    'version 1 database upgrades in place preserving user outcomes and schedules',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ontime-migration-',
      );
      final file = File('${directory.path}/v1.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: 'preserve',
            eligibleOutcomeCount: 4,
            onTimeOutcomeCount: 3,
          ),
        );
        await db.scheduleDao.createSchedule(
          ScheduleEntity(
            id: 'old',
            place: const PlaceEntity(id: 'p', placeName: 'Home'),
            scheduleName: 'Existing',
            scheduleTime: DateTime(2026, 1, 1, 10),
            moveTime: Duration.zero,
            isChanged: false,
            isStarted: false,
            scheduleNote: 'keep',
            scheduleSpareTime: Duration.zero,
          ).toScheduleWithPlaceRow(),
        );
        // The unchanged seven tables are schema 1 after removing the additive
        // recurrence migration. Reopen through the real onUpgrade entry point.
        for (final table in [
          'recurring_schedule_exclusions',
          'recurring_schedule_segments',
          'preparation_definition_steps',
          'preparation_definitions',
        ]) {
          await db.customStatement('DROP TABLE $table');
        }
        for (final column in [
          'recurring_segment_id',
          'recurring_slot_key',
          'recurring_ordinal',
          'recurring_overrides',
          'preparation_definition_id',
        ]) {
          await db.customStatement('ALTER TABLE schedules DROP COLUMN $column');
        }
        await db.customStatement('PRAGMA user_version = 1');
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        expect(
          (await db.scheduleDao.getScheduleById('old')).schedule.scheduleName,
          'Existing',
        );
        final user = (await db.userDao.getUserById('local-profile'))!;
        expect(user.note, 'preserve');
        expect(user.scoreOrNull, 75);
        expect(await db.select(db.recurringScheduleSegments).get(), isEmpty);
        expect(
          (await db.scheduleDao.getScheduleById(
            'old',
          )).schedule.recurringOverrides,
          '',
        );
        expect(
          (await db.customSelect('PRAGMA foreign_key_check').get()),
          isEmpty,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
