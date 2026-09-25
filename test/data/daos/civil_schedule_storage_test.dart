import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/mappers/domain_persistence_mappers.dart';
import 'package:on_time_front/data/mappers/recurrence_codec.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final example in [
    (literal: '2026-03-08T02:30:04.123456', zone: 'Asia/Seoul', offset: 32400),
    (
      literal: '2026-11-01T01:30:00.000',
      zone: 'America/New_York',
      offset: -14400,
    ),
    (
      literal: '2026-11-01T01:30:00.000',
      zone: 'America/New_York',
      offset: -18000,
    ),
    (literal: '2011-12-30T12:00:00.000', zone: 'Asia/Seoul', offset: 32400),
  ]) {
    test(
      'actual SQLite and recurrence codec preserve ${example.literal}/${example.offset}',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final civil = CivilDateTime.parse(example.literal);
        final value = ScheduleEntity(
          id: 'civil',
          place: const PlaceEntity(id: 'place', placeName: 'Place'),
          scheduleName: 'Original',
          scheduleTime: civil.toUtcCarrier(),
          timeZoneId: example.zone,
          occurrenceOffsetSeconds: example.offset,
          moveTime: Duration.zero,
          scheduleSpareTime: Duration.zero,
          isChanged: false,
          isStarted: false,
          scheduleNote: '',
        );
        await database.scheduleDao.createSchedule(
          value.toScheduleWithPlaceRow(),
        );
        final read = (await database.scheduleDao.getScheduleById(
          value.id,
        )).toScheduleEntity();
        expect(CivilDateTime.fromFields(read.scheduleTime), civil);
        expect(read.occurrenceOffsetSeconds, example.offset);
        expect(read.occurrenceInstantUtc, civil.atOffset(example.offset));
        await database.scheduleDao.updateScheduleWithPlace(
          read.copyWith(scheduleNote: 'Text only').toScheduleWithPlaceRow(),
        );
        final raw = await database
            .customSelect(
              'SELECT schedule_time, occurrence_offset_seconds FROM schedules',
            )
            .getSingle();
        expect(raw.read<String>('schedule_time'), example.literal);
        expect(raw.read<int>('occurrence_offset_seconds'), example.offset);
        final wire = RecurrenceCodec.scheduleToJson(read);
        expect(wire['time'], example.literal);
        final decoded = RecurrenceCodec.scheduleFromJson(wire);
        expect(CivilDateTime.fromFields(decoded.scheduleTime), civil);
        expect(decoded.occurrenceInstantUtc, civil.atOffset(example.offset));
        final rule = RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          start: civil.toUtcCarrier(),
          timeZoneId: example.zone,
        );
        expect(
          RecurrenceCodec.ruleFromJson(RecurrenceCodec.ruleToJson(rule)),
          rule,
        );
      },
    );
  }
}
