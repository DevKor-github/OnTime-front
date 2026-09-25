import 'package:on_time_front/domain/entities/civil_date_time.dart';
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
  DateTime fromSql(String fromDb) => CivilDateTime.parse(fromDb).toUtcCarrier();

  @override
  String toSql(DateTime value) =>
      CivilDateTime.fromFields(value).toCivilIso8601String();
}
