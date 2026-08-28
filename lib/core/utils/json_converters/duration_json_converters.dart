import 'package:drift/drift.dart';

class DurationSqlConverter extends TypeConverter<Duration, int>
    with JsonTypeConverter<Duration, int> {
  DurationSqlConverter();

  @override
  Duration fromSql(int fromDb) {
    return Duration(milliseconds: fromDb);
  }

  @override
  int toSql(Duration value) {
    return value.inMilliseconds;
  }
}

class CivilDateTimeSqlConverter extends TypeConverter<DateTime, String>
    with JsonTypeConverter<DateTime, String> {
  const CivilDateTimeSqlConverter();

  @override
  DateTime fromSql(String fromDb) {
    final parsed = DateTime.parse(fromDb);
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  @override
  String toSql(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  ).toIso8601String();
}
