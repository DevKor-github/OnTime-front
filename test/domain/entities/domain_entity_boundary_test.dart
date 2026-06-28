import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('domain entities do not import lower architectural layers', () {
    final domainEntityDirectory = Directory('lib/domain/entities');
    final forbiddenImportPattern = RegExp(
      r'''import\s+['"](?:(?:package:on_time_front/)|/)?(?:core|data|presentation)/''',
    );

    final violations = domainEntityDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('.freezed.dart'))
        .expand((file) {
          final lines = file.readAsLinesSync();
          return [
            for (var index = 0; index < lines.length; index++)
              if (forbiddenImportPattern.hasMatch(lines[index]))
                '${file.path}:${index + 1}: ${lines[index].trim()}',
          ];
        })
        .toList();

    expect(violations, isEmpty);
  });
}
