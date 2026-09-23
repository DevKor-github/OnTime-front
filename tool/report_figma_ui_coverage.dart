import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

const manifestPath = 'docs/design/figma_code_map.yaml';
const routerPath = 'lib/presentation/shared/router/go_router.dart';
const statuses = {'pending', 'in_progress', 'reviewed', 'excluded'};

void main(List<String> args) {
  final strict = args.contains('--strict');
  final manifest = loadYaml(File(manifestPath).readAsStringSync()) as YamlMap;
  final entries = manifest['screens'] as YamlList;
  final failures = <String>[];
  final routes = <String>{};
  final counts = <String, int>{};
  final variantCounts = <String, int>{};

  for (final value in entries) {
    final entry = value as YamlMap;
    final route = entry['route'] as String?;
    final status = entry['status'] as String?;
    if (route == null || !routes.add(route)) {
      failures.add('Missing or duplicate route: $route');
      continue;
    }
    if (!statuses.contains(status)) {
      failures.add('$route has invalid status: $status');
      continue;
    }
    counts[status!] = (counts[status] ?? 0) + 1;

    final nodeId = entry['figma_node'] as String?;
    if (nodeId != null && !RegExp(r'^\d+:\d+$').hasMatch(nodeId)) {
      failures.add('$route has malformed Figma node: $nodeId');
    }
    if (status == 'reviewed' && nodeId == null) {
      failures.add('$route is reviewed without a Figma node');
    }
    if (status == 'excluded' && entry['reason'] == null) {
      failures.add('$route is excluded without a reason');
    }

    final imagePath = entry['figma_image'] as String?;
    final expectedHash = entry['figma_sha256'] as String?;
    final goldenPath = entry['flutter_golden'] as String?;
    if ((imagePath == null) != (expectedHash == null)) {
      failures.add('$route must pair Figma image with its SHA-256');
    }
    if (imagePath != null) {
      final image = File(imagePath);
      if (!image.existsSync()) {
        failures.add('$route is missing Figma image: $imagePath');
      } else if (sha256.convert(image.readAsBytesSync()).toString() !=
          expectedHash) {
        failures.add('$route Figma image hash changed: $imagePath');
      }
    }
    if (goldenPath != null && !File(goldenPath).existsSync()) {
      failures.add('$route is missing Flutter golden: $goldenPath');
    }
    if (status == 'reviewed' && (imagePath == null || goldenPath == null)) {
      failures.add('$route is reviewed without both comparison images');
    }

    final variants = entry['variants'] as YamlList?;
    final states = <String>{};
    for (final value in variants ?? <Object>[]) {
      final variant = value as YamlMap;
      final state = variant['state'] as String?;
      final label = '$route/$state';
      final variantStatus = variant['status'] as String?;
      if (state == null || !states.add(state)) {
        failures.add('$route has a missing or duplicate variant state: $state');
      }
      if (!statuses.contains(variantStatus)) {
        failures.add('$label has invalid status: $variantStatus');
        continue;
      }
      variantCounts[variantStatus!] = (variantCounts[variantStatus] ?? 0) + 1;

      final variantNode = variant['figma_node'] as String?;
      if (variantNode == null || !RegExp(r'^\d+:\d+$').hasMatch(variantNode)) {
        failures.add('$label has missing or malformed Figma node');
      }
      if (variantStatus == 'excluded' && variant['reason'] == null) {
        failures.add('$label is excluded without a reason');
      }

      final variantImagePath = variant['figma_image'] as String?;
      final variantHash = variant['figma_sha256'] as String?;
      final variantGoldenPath = variant['flutter_golden'] as String?;
      if ((variantImagePath == null) != (variantHash == null)) {
        failures.add('$label must pair Figma image with its SHA-256');
      }
      if (variantImagePath != null) {
        final image = File(variantImagePath);
        if (!image.existsSync()) {
          failures.add('$label is missing Figma image: $variantImagePath');
        } else if (sha256.convert(image.readAsBytesSync()).toString() !=
            variantHash) {
          failures.add('$label Figma image hash changed: $variantImagePath');
        }
      }
      if (variantGoldenPath != null && !File(variantGoldenPath).existsSync()) {
        failures.add('$label is missing Flutter golden: $variantGoldenPath');
      }
      if (variantStatus == 'reviewed' &&
          (variantImagePath == null || variantGoldenPath == null)) {
        failures.add('$label is reviewed without both comparison images');
      }
    }
  }

  final router = File(routerPath).readAsStringSync();
  final declaredRoutes = RegExp(r"path:\s*'(/[^']+)'", multiLine: true)
      .allMatches(router)
      .map((match) => match.group(1)!)
      .map((route) => route == '/start' ? '/onboarding/start' : route)
      .toSet();
  for (final route in declaredRoutes.difference(routes)) {
    failures.add('Router path has no Figma coverage entry: $route');
  }
  for (final route in routes.difference(declaredRoutes)) {
    failures.add('Coverage entry has no router path: $route');
  }

  stdout.writeln(
    'Figma UI coverage: ${entries.length} routes; '
    'reviewed ${counts['reviewed'] ?? 0}, '
    'in progress ${counts['in_progress'] ?? 0}, '
    'pending ${counts['pending'] ?? 0}, '
    'excluded ${counts['excluded'] ?? 0}; '
    'variants reviewed ${variantCounts['reviewed'] ?? 0}, '
    'in progress ${variantCounts['in_progress'] ?? 0}, '
    'pending ${variantCounts['pending'] ?? 0}, '
    'excluded ${variantCounts['excluded'] ?? 0}.',
  );
  if (strict &&
      (counts['pending'] ?? 0) +
              (counts['in_progress'] ?? 0) +
              (variantCounts['pending'] ?? 0) +
              (variantCounts['in_progress'] ?? 0) >
          0) {
    failures.add(
      'Strict Figma UI coverage requires all routes and variants reviewed or excluded.',
    );
  }
  for (final failure in failures) {
    stderr.writeln(failure);
  }
  if (failures.isNotEmpty) exitCode = 1;
}
