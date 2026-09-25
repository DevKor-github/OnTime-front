// Actual repository writer + SQLite consumer regression. The rule-zone mutation
// models unavailable historical rules; this is not an encrypted restore test.
import 'dart:convert';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';

void main() {
  const removedZone = 'Old/Removed_Test_Zone';
  const preparation = PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'source-step',
        preparationName: 'Get ready',
        preparationTime: Duration(minutes: 10),
      ),
    ],
  );
  ScheduleEntity schedule(String id, DateTime at) => ScheduleEntity(
    id: id,
    place: PlaceEntity(id: 'place-$id', placeName: 'Office'),
    scheduleName: id,
    scheduleTime: at,
    timeZoneId: 'UTC',
    occurrenceOffsetSeconds: 0,
    moveTime: Duration.zero,
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: Duration.zero,
    scheduleNote: 'Keep original history',
  );
  for (final queryPast in [false, true]) {
    test(
      'unknown past until preserves rows and permits known future generation, past query=$queryPast',
      () async {
        var now = DateTime.utc(2019, 12, 31);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repository = RecurringScheduleRepositoryImpl(db, now: () => now);
        await db.userDao.putUser(
          const UserEntity(
            id: 'local-profile',
            spareTime: Duration.zero,
            note: '',
            isOnboardingCompleted: true,
          ),
        );
        final past = DateTime.utc(2020, 1, 1, 10);
        await repository.create(
          schedule('history', past),
          preparation,
          RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            start: past,
            timeZoneId: 'UTC',
            until: DateTime.utc(2020, 1, 3),
          ),
        );
        final history = (await repository.getSegments()).single;
        now = DateTime.utc(2030, 1, 1);
        final future = DateTime.utc(2030, 1, 2, 10);
        await repository.create(
          schedule('future', future),
          preparation,
          RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            start: future,
            timeZoneId: 'UTC',
            count: 65,
          ),
        );
        final known = (await repository.getSegments()).singleWhere(
          (s) => s.seriesId == 'future',
        );
        final segment = await (db.select(
          db.recurringScheduleSegments,
        )..where((t) => t.id.equals(history.id))).getSingle();
        final rule = jsonDecode(segment.ruleJson) as Map<String, dynamic>;
        final prototype =
            jsonDecode(segment.scheduleJson) as Map<String, dynamic>;
        rule['zone'] = removedZone;
        prototype['zone'] = removedZone;
        await (db.update(
          db.recurringScheduleSegments,
        )..where((t) => t.id.equals(history.id))).write(
          RecurringScheduleSegmentsCompanion(
            ruleJson: Value(jsonEncode(rule)),
            scheduleJson: Value(jsonEncode(prototype)),
          ),
        );
        await (db.update(db.schedules)
              ..where((t) => t.recurringSegmentId.equals(history.id)))
            .write(const SchedulesCompanion(timeZoneId: Value(removedZone)));
        Future<List<Map<String, dynamic>>> historicalRows() async =>
            (await db
                    .customSelect(
                      'SELECT * FROM schedules WHERE recurring_segment_id = ? ORDER BY id',
                      variables: [Variable.withString(history.id)],
                    )
                    .get())
                .map((row) => row.data)
                .toList();
        Future<int> knownCount() async => (await (db.select(
          db.schedules,
        )..where((t) => t.recurringSegmentId.equals(known.id))).get()).length;
        final beforeRows = await historicalRows();
        final beforeSegment = await (db.select(
          db.recurringScheduleSegments,
        )..where((t) => t.id.equals(history.id))).getSingle();
        expect(beforeRows, hasLength(3));
        expect(await knownCount(), 60);
        await repository.materialize(
          queryPast ? DateTime.utc(2019) : now,
          DateTime.utc(2030, 4, 1),
        );
        expect(await knownCount(), 65);
        expect(await historicalRows(), beforeRows);
        expect(
          await (db.select(
            db.recurringScheduleSegments,
          )..where((t) => t.id.equals(history.id))).getSingle(),
          beforeSegment,
        );
        expect(
          (await historicalRows()).every((row) => row['is_started'] == 0),
          isTrue,
        );
      },
    );
  }
}
