import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/recurrence/recurrence_rule.dart';

abstract final class RecurrenceCodec {
  static Map<String, dynamic> ruleToJson(RecurrenceRule r) => {
    'frequency': r.frequency.name,
    'start': r.start.toIso8601String(),
    'zone': r.timeZoneId,
    'interval': r.interval,
    'weekdays': r.weekdays.toList()..sort(),
    'monthly': r.monthly.name,
    'monthDay': r.monthDay,
    'ordinal': r.ordinal,
    'monthWeekday': r.monthWeekday,
    'until': r.until?.toIso8601String(),
    'count': r.count,
    'repeatedTime': r.repeatedTime?.name,
  };
  static RecurrenceRule ruleFromJson(Map<String, dynamic> j) => RecurrenceRule(
    frequency: RecurrenceFrequency.values.byName(j['frequency'] as String),
    start: DateTime.parse(j['start'] as String),
    timeZoneId: j['zone'] as String,
    interval: j['interval'] as int,
    weekdays: (j['weekdays'] as List).cast<int>().toSet(),
    monthly: MonthlyRecurrence.values.byName(j['monthly'] as String),
    monthDay: j['monthDay'] as int,
    ordinal: j['ordinal'] as int,
    monthWeekday: j['monthWeekday'] as int,
    count: j['count'] as int?,
    until: j['until'] == null ? null : DateTime.parse(j['until'] as String),
    repeatedTime: j['repeatedTime'] == null
        ? null
        : RepeatedCivilTime.values.byName(j['repeatedTime'] as String),
  );
  static Map<String, dynamic> scheduleToJson(ScheduleEntity s) => {
    'id': s.id,
    'placeId': s.place.id,
    'place': s.place.placeName,
    'name': s.scheduleName,
    'time': s.scheduleTime.toIso8601String(),
    'zone': s.timeZoneId,
    'offset': s.occurrenceOffsetSeconds,
    'move': s.moveTime.inMinutes,
    'spare': s.scheduleSpareTime?.inMinutes,
    'note': s.scheduleNote,
  };
  static ScheduleEntity scheduleFromJson(Map<String, dynamic> j) =>
      ScheduleEntity(
        id: j['id'] as String,
        place: PlaceEntity(
          id: j['placeId'] as String,
          placeName: j['place'] as String,
        ),
        scheduleName: j['name'] as String,
        scheduleTime: DateTime.parse(j['time'] as String),
        timeZoneId: j['zone'] as String,
        occurrenceOffsetSeconds: j['offset'] as int?,
        moveTime: Duration(minutes: j['move'] as int),
        scheduleSpareTime: j['spare'] == null
            ? null
            : Duration(minutes: j['spare'] as int),
        scheduleNote: j['note'] as String,
        isChanged: false,
        isStarted: false,
      );
}
