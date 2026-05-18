import 'dart:io';

const _defaultCoveragePath = 'coverage/lcov.info';
const _defaultMinimum = 80.0;

void main(List<String> arguments) {
  final options = _CoverageOptions.parse(arguments);
  final file = File(options.coveragePath);

  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: ${options.coveragePath}');
    stderr.writeln('Run `flutter test --coverage` before checking coverage.');
    exitCode = 1;
    return;
  }

  final report = _LcovReport.parse(file.readAsLinesSync());

  if (report.totalLines == 0) {
    stderr.writeln(
      'No app-owned coverage data found in ${options.coveragePath}.',
    );
    exitCode = 1;
    return;
  }

  final percentage = report.percentage;
  final formattedPercentage = percentage.toStringAsFixed(2);
  final formattedMinimum = options.minimum.toStringAsFixed(2);

  stdout.writeln(
    'Coverage: $formattedPercentage% '
    '(${report.coveredLines}/${report.totalLines} lines)',
  );

  if (percentage < options.minimum) {
    stderr.writeln(
      'Coverage check failed: $formattedPercentage% is below '
      'the required $formattedMinimum%.',
    );
    exitCode = 1;
  }
}

class _CoverageOptions {
  const _CoverageOptions({required this.coveragePath, required this.minimum});

  final String coveragePath;
  final double minimum;

  static _CoverageOptions parse(List<String> arguments) {
    var coveragePath = _defaultCoveragePath;
    var minimum = _defaultMinimum;

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];

      if (argument == '--coverage') {
        coveragePath = _requiredValue(arguments, index, argument);
        index += 1;
      } else if (argument.startsWith('--coverage=')) {
        coveragePath = argument.substring('--coverage='.length);
      } else if (argument == '--min') {
        minimum = _parseMinimum(_requiredValue(arguments, index, argument));
        index += 1;
      } else if (argument.startsWith('--min=')) {
        minimum = _parseMinimum(argument.substring('--min='.length));
      } else {
        stderr.writeln('Unknown argument: $argument');
        _printUsageAndExit();
      }
    }

    return _CoverageOptions(coveragePath: coveragePath, minimum: minimum);
  }

  static String _requiredValue(
    List<String> arguments,
    int index,
    String option,
  ) {
    final valueIndex = index + 1;
    if (valueIndex >= arguments.length ||
        arguments[valueIndex].startsWith('--')) {
      stderr.writeln('Missing value for $option.');
      _printUsageAndExit();
    }
    return arguments[valueIndex];
  }

  static double _parseMinimum(String value) {
    final minimum = double.tryParse(value);
    if (minimum == null || minimum < 0 || minimum > 100) {
      stderr.writeln('Invalid coverage minimum: $value');
      _printUsageAndExit();
    }
    return minimum;
  }

  static Never _printUsageAndExit() {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart '
      '[--coverage coverage/lcov.info] [--min 80]',
    );
    exit(64);
  }
}

class _LcovReport {
  const _LcovReport({required this.coveredLines, required this.totalLines});

  final int coveredLines;
  final int totalLines;

  double get percentage => coveredLines / totalLines * 100;

  static _LcovReport parse(List<String> lines) {
    var currentSourceFile = '';
    var currentCoveredLines = 0;
    var currentTotalLines = 0;
    var coveredLines = 0;
    var totalLines = 0;

    void flushRecord() {
      if (_isIncludedSource(currentSourceFile)) {
        coveredLines += currentCoveredLines;
        totalLines += currentTotalLines;
      }

      currentSourceFile = '';
      currentCoveredLines = 0;
      currentTotalLines = 0;
    }

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        flushRecord();
        currentSourceFile = _normalizePath(line.substring(3));
      } else if (line.startsWith('LH:')) {
        currentCoveredLines = _parseCount(line, 'LH');
      } else if (line.startsWith('LF:')) {
        currentTotalLines = _parseCount(line, 'LF');
      } else if (line == 'end_of_record') {
        flushRecord();
      }
    }

    flushRecord();

    return _LcovReport(coveredLines: coveredLines, totalLines: totalLines);
  }

  static int _parseCount(String line, String label) {
    final value = int.tryParse(line.substring(label.length + 1));
    if (value == null) {
      stderr.writeln('Invalid LCOV $label value: $line');
      exit(1);
    }
    return value;
  }
}

String _normalizePath(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  final libIndex = normalizedPath.indexOf('/lib/');

  if (libIndex == -1) {
    return normalizedPath;
  }

  return normalizedPath.substring(libIndex + 1);
}

bool _isIncludedSource(String sourceFile) {
  if (!sourceFile.startsWith('lib/')) {
    return false;
  }

  if (sourceFile.endsWith('.g.dart') ||
      sourceFile.endsWith('.freezed.dart') ||
      sourceFile.endsWith('.config.dart') ||
      sourceFile.endsWith('.mocks.dart')) {
    return false;
  }

  if (sourceFile == 'lib/firebase_options.dart') {
    return false;
  }

  if (sourceFile == 'lib/core/database/database.dart' ||
      sourceFile.startsWith('lib/data/tables/')) {
    return false;
  }

  if (sourceFile.startsWith('lib/l10n/app_localizations') &&
      sourceFile.endsWith('.dart')) {
    return false;
  }

  return true;
}
