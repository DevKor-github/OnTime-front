import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/data_sources/schedule_local_data_source.dart';
import 'package:on_time_front/data/tables/schedule_with_place_model.dart';

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
    final schedule = _scheduleWithPlace(
      id: 'schedule-1',
      placeId: 'place-1',
      placeName: 'Office',
      time: DateTime(2026, 5, 15, 9),
    );

    await dataSource.createSchedule(schedule);

    final stored = await dataSource.getScheduleById('schedule-1');
    expect(stored.schedule.id, 'schedule-1');
    expect(stored.place, const Place(id: 'place-1', placeName: 'Office'));
    expect(stored.schedule.scheduleName, 'Meeting schedule-1');
    expect(stored.schedule.scheduleTime, DateTime(2026, 5, 15, 9));
    expect(stored.schedule.moveTime, const Duration(minutes: 20));
    expect(stored.schedule.scheduleSpareTime, const Duration(minutes: 5));
  });

  test('filters schedules by date range and updates schedule fields', () async {
    final inside = _scheduleWithPlace(
      id: 'inside',
      placeId: 'place-1',
      placeName: 'Office',
      time: DateTime(2026, 5, 15, 9),
    );
    final outside = _scheduleWithPlace(
      id: 'outside',
      placeId: 'place-2',
      placeName: 'Cafe',
      time: DateTime(2026, 5, 17, 9),
    );
    await dataSource.createSchedule(inside);
    await dataSource.createSchedule(outside);

    final updated = _scheduleRow(
      id: 'inside',
      placeId: 'place-1',
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

    expect(schedules.map((schedule) => schedule.schedule.id), ['inside']);
    expect(schedules.single.schedule.scheduleName, 'Updated meeting');
    expect(schedules.single.schedule.scheduleTime, DateTime(2026, 5, 15, 10));
    expect(schedules.single.schedule.moveTime, const Duration(minutes: 45));
    expect(schedules.single.schedule.isChanged, isTrue);
    expect(schedules.single.schedule.isStarted, isTrue);
    expect(
      schedules.single.schedule.scheduleSpareTime,
      const Duration(minutes: 15),
    );
    expect(schedules.single.schedule.scheduleNote, 'updated note');
    expect(schedules.single.schedule.latenessTime, 2);
  });

  test(
    'filters schedule date ranges as start-inclusive and end-exclusive',
    () async {
      final startBoundary = _scheduleWithPlace(
        id: 'start-boundary',
        placeId: 'place-1',
        placeName: 'Office',
        time: DateTime(2026, 2, 1),
      );
      final lastDay = _scheduleWithPlace(
        id: 'last-day',
        placeId: 'place-2',
        placeName: 'Cafe',
        time: DateTime(2026, 2, 28, 23, 59),
      );
      final nextMonthStart = _scheduleWithPlace(
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
        schedules.map((schedule) => schedule.schedule.id),
        unorderedEquals(['start-boundary', 'last-day']),
      );
    },
  );

  test('deleteSchedule removes only the requested schedule', () async {
    await dataSource.createSchedule(
      _scheduleWithPlace(
        id: 'schedule-1',
        placeId: 'place-1',
        placeName: 'Office',
        time: DateTime(2026, 5, 15, 9),
      ),
    );
    final keep = _scheduleWithPlace(
      id: 'schedule-2',
      placeId: 'place-2',
      placeName: 'Cafe',
      time: DateTime(2026, 5, 15, 11),
    );
    await dataSource.createSchedule(keep);

    await dataSource.deleteSchedule(
      _scheduleRow(
        id: 'schedule-1',
        placeId: 'place-1',
        scheduleName: 'Meeting schedule-1',
        scheduleTime: DateTime(2026, 5, 15, 9),
        moveTime: const Duration(minutes: 20),
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: const Duration(minutes: 5),
        scheduleNote: 'note',
        latenessTime: -1,
      ),
    );

    final schedules = await dataSource.getSchedulesByDate(
      DateTime(2026, 5, 15),
      DateTime(2026, 5, 16),
    );
    expect(schedules, [keep]);
  });
}

ScheduleWithPlace _scheduleWithPlace({
  required String id,
  required String placeId,
  required String placeName,
  required DateTime time,
}) {
  return ScheduleWithPlace(
    schedule: _scheduleRow(
      id: id,
      placeId: placeId,
      scheduleName: 'Meeting $id',
      scheduleTime: time,
      moveTime: const Duration(minutes: 20),
      isChanged: false,
      isStarted: false,
      scheduleSpareTime: const Duration(minutes: 5),
      scheduleNote: 'note',
      latenessTime: -1,
    ),
    place: Place(id: placeId, placeName: placeName),
  );
}

Schedule _scheduleRow({
  required String id,
  required String placeId,
  required String scheduleName,
  required DateTime scheduleTime,
  required Duration moveTime,
  required bool isChanged,
  required bool isStarted,
  required Duration? scheduleSpareTime,
  required String? scheduleNote,
  required int latenessTime,
}) {
  return Schedule(
    id: id,
    placeId: placeId,
    scheduleName: scheduleName,
    scheduleTime: scheduleTime,
    moveTime: moveTime,
    isChanged: isChanged,
    isStarted: isStarted,
    scheduleSpareTime: scheduleSpareTime,
    scheduleNote: scheduleNote,
    latenessTime: latenessTime,
  );
}
