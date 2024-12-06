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
