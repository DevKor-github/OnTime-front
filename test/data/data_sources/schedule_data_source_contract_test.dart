import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'schedule remote data source contract does not expose domain entities',
    () {
      final violations = _scheduleEntityViolations(
        'lib/data/data_sources/schedule_remote_data_source.dart',
      );

      expect(violations, isEmpty);
    },
  );

  test(
    'schedule local data source contract does not expose domain entities',
    () {
      final violations = _scheduleEntityViolations(
        'lib/data/data_sources/schedule_local_data_source.dart',
      );

      expect(violations, isEmpty);
    },
  );
}

List<String> _scheduleEntityViolations(String path) {
  final lines = File(path).readAsLinesSync();
  return [
    for (var index = 0; index < lines.length; index++)
      if (lines[index].contains('domain/entities/schedule_entity.dart') ||
          lines[index].contains('ScheduleEntity'))
        '$path:${index + 1}: ${lines[index].trim()}',
  ];
}
