import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('repository structure', () {
    test('source and test directories do not use .dart suffixes', () {
      final dartDirectories =
          _directoriesUnder(['lib', 'test'])
              .where(
                (directory) =>
                    _lastPathSegment(directory.path).endsWith('.dart'),
              )
              .map(_relativePath)
              .toList()
            ..sort();

      expect(dartDirectories, isEmpty);
    });

    test('schedule place moving time imports use the folder path', () {
      final obsoleteSegment =
          'schedule_place_moving_time'
          '.dart/';
      final offenders =
          _dartFilesUnder([
              'lib',
              'test',
            ]).expand((file) => _matchingLines(file, obsoleteSegment)).toList()
            ..sort();

      expect(offenders, isEmpty);
    });
  });
}

Iterable<Directory> _directoriesUnder(List<String> rootPaths) sync* {
  for (final rootPath in rootPaths) {
    final root = Directory(rootPath);
    if (!root.existsSync()) {
      continue;
    }

    yield* root
        .listSync(recursive: true, followLinks: false)
        .whereType<Directory>();
  }
}

Iterable<File> _dartFilesUnder(List<String> rootPaths) sync* {
  for (final rootPath in rootPaths) {
    final root = Directory(rootPath);
    if (!root.existsSync()) {
      continue;
    }

    yield* root
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
  }
}

Iterable<String> _matchingLines(File file, String pattern) sync* {
  final lines = file.readAsLinesSync();

  for (var index = 0; index < lines.length; index += 1) {
    if (lines[index].contains(pattern)) {
      yield '${_relativePath(file)}:${index + 1}';
    }
  }
}

String _lastPathSegment(String path) => path.split(Platform.pathSeparator).last;

String _relativePath(FileSystemEntity entity) {
  final currentPath = Directory.current.path;
  final entityPath = entity.path;
  final prefix = '$currentPath${Platform.pathSeparator}';

  return entityPath.startsWith(prefix)
      ? entityPath.substring(prefix.length)
      : entityPath;
}
