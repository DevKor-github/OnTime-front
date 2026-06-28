import 'dart:io';

const _generatedPatterns = [
  '*.g.dart',
  '*.config.dart',
  '*.freezed.dart',
  '*.mocks.dart',
];

const _ignoredExamples = [
  'lib/core/database/database.g.dart',
  'lib/core/di/di_setup.config.dart',
  'lib/domain/entities/schedule.freezed.dart',
  'test/helpers/mock_repositories.mocks.dart',
  'widgetbook/lib/main.directories.g.dart',
];

void main() {
  final repoRoot = _repoRoot();
  final failures = <String>[];

  final trackedGenerated = _gitLines(repoRoot, [
    'ls-files',
    '--',
    ..._generatedPatterns,
  ]);
  if (trackedGenerated.isNotEmpty) {
    failures.add(
      'Generated Dart outputs must not be tracked:\n'
      '${trackedGenerated.map((path) => '  - $path').join('\n')}',
    );
  }

  final missingIgnores = <String>[];
  for (final path in _ignoredExamples) {
    final result = Process.runSync('git', [
      'check-ignore',
      '-q',
      '--',
      path,
    ], workingDirectory: repoRoot);
    if (result.exitCode != 0) {
      missingIgnores.add(path);
    }
  }

  if (missingIgnores.isNotEmpty) {
    failures.add(
      'Generated Dart outputs must stay ignored:\n'
      '${missingIgnores.map((path) => '  - $path').join('\n')}',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Generated Dart policy check failed.');
    stderr.writeln(failures.join('\n\n'));
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Generated Dart policy is aligned: outputs are ignored and untracked.',
  );
}

String _repoRoot() {
  final result = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (result.exitCode != 0) {
    stderr.writeln('Unable to locate git repository root.');
    stderr.write(result.stderr);
    exit(1);
  }
  return (result.stdout as String).trim();
}

List<String> _gitLines(String workingDirectory, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    stderr.writeln('git ${arguments.join(' ')} failed.');
    stderr.write(result.stderr);
    exit(1);
  }

  final output = (result.stdout as String).trim();
  if (output.isEmpty) {
    return const [];
  }
  return output.split('\n');
}
