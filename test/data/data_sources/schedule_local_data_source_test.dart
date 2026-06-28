import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';

void main() {
  late AppDatabase database;
  late ScheduleLocalDataSourceImpl dataSource;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = ScheduleLocalDataSourceImpl(appDatabase: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates and reads a schedule with its place', () async {
    final schedule = _schedule(
      id: 'schedule-1',
      placeId: 'place-1',
      placeName: 'Office',
      time: DateTime(2026, 5, 15, 9),
    );

    await dataSource.createSchedule(schedule);

    final stored = await dataSource.getScheduleById('schedule-1');
    expect(stored.id, 'schedule-1');
    expect(stored.place, const PlaceEntity(id: 'place-1', placeName: 'Office'));
    expect(stored.scheduleName, 'Meeting schedule-1');
    expect(stored.scheduleTime, DateTime(2026, 5, 15, 9));
    expect(stored.moveTime, const Duration(minutes: 20));
    expect(stored.scheduleSpareTime, const Duration(minutes: 5));
  });

  test('filters schedules by date range and updates schedule fields', () async {
    final inside = _schedule(
      id: 'inside',
      placeId: 'place-1',
      placeName: 'Office',
      time: DateTime(2026, 5, 15, 9),
    );
    final outside = _schedule(
      id: 'outside',
      placeId: 'place-2',
      placeName: 'Cafe',
      time: DateTime(2026, 5, 17, 9),
    );
    await dataSource.createSchedule(inside);
    await dataSource.createSchedule(outside);

    final updated = ScheduleEntity(
      id: 'inside',
      place: const PlaceEntity(id: 'place-1', placeName: 'Ignored by update'),
      scheduleName: 'Updated meeting',
      scheduleTime: DateTime(2026, 5, 15, 10),
      moveTime: const Duration(minutes: 45),
      isChanged: true,
      isStarted: true,
      scheduleSpareTime: const Duration(minutes: 15),
      scheduleNote: 'updated note',
      latenessTime: 2,
    );
    await dataSource.updateSchedule(updated);

    final schedules = await dataSource.getSchedulesByDate(
      DateTime(2026, 5, 15),
      DateTime(2026, 5, 16),
    );

    expect(schedules.map((schedule) => schedule.id), ['inside']);
    expect(schedules.single.scheduleName, 'Updated meeting');
    expect(schedules.single.scheduleTime, DateTime(2026, 5, 15, 10));
    expect(schedules.single.moveTime, const Duration(minutes: 45));
    expect(schedules.single.isChanged, isTrue);
    expect(schedules.single.isStarted, isTrue);
    expect(schedules.single.scheduleSpareTime, const Duration(minutes: 15));
    expect(schedules.single.scheduleNote, 'updated note');
    expect(schedules.single.latenessTime, 2);
  });

  test(
    'filters schedule date ranges as start-inclusive and end-exclusive',
    () async {
      final startBoundary = _schedule(
        id: 'start-boundary',
        placeId: 'place-1',
        placeName: 'Office',
        time: DateTime(2026, 2, 1),
      );
      final lastDay = _schedule(
        id: 'last-day',
        placeId: 'place-2',
        placeName: 'Cafe',
        time: DateTime(2026, 2, 28, 23, 59),
      );
      final nextMonthStart = _schedule(
        id: 'next-month-start',
        placeId: 'place-3',
        placeName: 'Station',
        time: DateTime(2026, 3, 1),
      );
      await dataSource.createSchedule(startBoundary);
      await dataSource.createSchedule(lastDay);
      await dataSource.createSchedule(nextMonthStart);

      final schedules = await dataSource.getSchedulesByDate(
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      );

      expect(
        schedules.map((schedule) => schedule.id),
        unorderedEquals(['start-boundary', 'last-day']),
      );
    },
  );

  test('deleteSchedule removes only the requested schedule', () async {
    await dataSource.createSchedule(
      _schedule(
        id: 'schedule-1',
        placeId: 'place-1',
        placeName: 'Office',
        time: DateTime(2026, 5, 15, 9),
      ),
    );
    final keep = _schedule(
      id: 'schedule-2',
      placeId: 'place-2',
      placeName: 'Cafe',
      time: DateTime(2026, 5, 15, 11),
    );
    await dataSource.createSchedule(keep);

    await dataSource.deleteSchedule(
      _schedule(
        id: 'schedule-1',
        placeId: 'place-1',
        placeName: 'Office',
        time: DateTime(2026, 5, 15, 9),
      ),
    );

    final schedules = await dataSource.getSchedulesByDate(
      DateTime(2026, 5, 15),
      DateTime(2026, 5, 16),
    );
    expect(schedules, [keep]);
  });
}

ScheduleEntity _schedule({
  required String id,
  required String placeId,
  required String placeName,
  required DateTime time,
}) {
  return ScheduleEntity(
    id: id,
    place: PlaceEntity(id: placeId, placeName: placeName),
    scheduleName: 'Meeting $id',
    scheduleTime: time,
    moveTime: const Duration(minutes: 20),
    isChanged: false,
    isStarted: false,
    scheduleSpareTime: const Duration(minutes: 5),
    scheduleNote: 'note',
  );
}
