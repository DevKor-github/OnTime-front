import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';

void main() {
  test(
    'version 1 database upgrades in place preserving user outcomes and schedules',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ontime-migration-',
      );
      final file = File('${directory.path}/v1.sqlite');
      final raw = sqlite3.open(file.path);
      raw.execute(
        File('test/fixtures/database/schema_v1.sql').readAsStringSync(),
      );
      raw.execute(
        "INSERT INTO users(id,spare_time,note,eligible_outcome_count,on_time_outcome_count) VALUES('local-profile',0,'preserve',4,3)",
      );
      raw.execute("INSERT INTO places(id,place_name) VALUES('p','Home')");
      raw.execute(
        "INSERT INTO schedules(id,place_id,schedule_name,schedule_time,move_time,schedule_note) VALUES('old','p','Existing','2026-01-01T10:00:00.000',0,'keep')",
      );
      raw.dispose();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
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
