import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/repositories/recurring_schedule_repository_impl.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';

void main() {
  late Directory directory;
  late AppDatabase db;
  late RecurringScheduleRepositoryImpl repository;
  final start = DateTime.utc(2030, 1, 2, 10);
  const preparation = PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'source-step',
        preparationName: 'Get ready',
        preparationTime: Duration(minutes: 10),
      ),
    ],
  );

  Future<void> open() async {
    db = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/app.sqlite')),
    );
    repository = RecurringScheduleRepositoryImpl(
      db,
      now: () => DateTime.utc(2030, 1, 1),
    );
  }

  Future<List<ScheduleEntity>> rows() async =>
      (await db.scheduleDao.getScheduleList())
          .map((row) => row.toScheduleEntity())
          .toList()
        ..sort((a, b) => a.scheduleTime.compareTo(b.scheduleTime));

  RecurrenceRule rule(DateTime at) => RecurrenceRule(
    frequency: RecurrenceFrequency.daily,
    start: at,
    timeZoneId: 'UTC',
    count: 3,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ontime-time-override-');
    await open();
    await db.userDao.putUser(
      const UserEntity(
        id: 'local-profile',
        spareTime: Duration.zero,
        note: '',
        isOnboardingCompleted: true,
      ),
    );
    await repository.create(
      ScheduleEntity(
        id: 'series',
        place: const PlaceEntity(id: 'place', placeName: 'Office'),
        scheduleName: 'Meeting',
        scheduleTime: start,
        timeZoneId: 'UTC',
        occurrenceOffsetSeconds: 0,
        moveTime: Duration.zero,
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: Duration.zero,
        scheduleNote: 'Keep the appointment',
      ),
      preparation,
      rule(start),
    );
  });

  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'a zone-only edit with the same offset is an explicit time override',
    () async {
      final original = (await rows())[1];
      await repository.updateOccurrence(
        original,
        original.copyWith(timeZoneId: 'Africa/Abidjan'),
        preparation,
        preparationChanged: false,
      );
      final updated = (await rows()).singleWhere(
        (row) => row.id == original.id,
      );
      expect(updated.scheduleTime, DateTime.utc(2030, 1, 3, 10));
      expect(updated.timeZoneId, 'Africa/Abidjan');
      expect(updated.occurrenceOffsetSeconds, 0);
      expect(updated.recurringOverrides.split(','), contains('time'));
      expect(updated.recurringSlotKey, original.recurringSlotKey);
      expect(updated.recurringOrdinal, original.recurringOrdinal);
    },
  );

  for (final choice in [
    (zone: 'Africa/Abidjan', offset: 0, utcHour: 10),
    (zone: 'Asia/Seoul', offset: 32400, utcHour: 1),
  ]) {
    test(
      'following edits and reopen preserve the complete ${choice.zone} time override',
      () async {
        final initial = await rows();
        final original = initial[1];
        await repository.updateOccurrence(
          original,
          original.copyWith(
            timeZoneId: choice.zone,
            occurrenceOffsetSeconds: choice.offset,
          ),
          preparation,
          preparationChanged: false,
        );
        // Exercise the public workflow, not _mergeOverrides or fabricated rows.
        // Change the base hour so a missing time mask is observable as well.
        final newStart = start.add(const Duration(hours: 1));
        await repository.updateFollowing(
          initial.first,
          initial.first.copyWith(scheduleTime: newStart),
          preparation,
          rule(newStart),
        );
        await repository.materialize(start, DateTime.utc(2030, 1, 8));
        final beforeReopen = await rows();
        expect(beforeReopen, hasLength(3));
        final overridden = beforeReopen.singleWhere(
          (row) => row.scheduleTime.day == 3,
        );
        expect(overridden.scheduleTime, DateTime.utc(2030, 1, 3, 10));
        expect(overridden.timeZoneId, choice.zone);
        expect(overridden.occurrenceOffsetSeconds, choice.offset);
        expect(
          overridden.occurrenceInstantUtc,
          DateTime.utc(2030, 1, 3, choice.utcHour),
        );
        expect(overridden.recurringOverrides.split(','), contains('time'));
        expect(
          beforeReopen
              .where((row) => row.scheduleTime.day != 3)
              .map((row) => row.scheduleTime.hour),
          [11, 11],
        );
        expect(
          beforeReopen
              .where((row) => row.scheduleTime.day != 3)
              .map((row) => row.timeZoneId),
          everyElement('UTC'),
        );

        final savedIds = beforeReopen.map((row) => row.id).toList();
        await db.close();
        await open();
        await repository.materialize(start, DateTime.utc(2030, 1, 8));
        final reopened = await rows();
        expect(reopened.map((row) => row.id), savedIds);
        final retained = reopened.singleWhere(
          (row) => row.scheduleTime.day == 3,
        );
        expect(retained.scheduleTime, DateTime.utc(2030, 1, 3, 10));
        expect(retained.timeZoneId, choice.zone);
        expect(retained.occurrenceOffsetSeconds, choice.offset);
        expect(
          retained.occurrenceInstantUtc,
          DateTime.utc(2030, 1, 3, choice.utcHour),
        );
      },
    );
  }
}
