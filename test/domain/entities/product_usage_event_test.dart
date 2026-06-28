import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/product_usage_event.dart';
import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

void main() {
  test('schedule_created factory builds the catalog event', () {
    final event = ProductUsageEvent.scheduleCreated(
      preparationMode: SchedulePreparationMode.custom,
      preparationStepCount: 3,
      minutesUntilSchedule: 45,
    );

    expect(event.name, 'schedule_created');
    expect(event.workflow, 'schedule');
    expect(event.result, 'success');
    expect(event.parameters, {
      'preparation_mode': 'custom',
      'preparation_step_count': 3,
      'minutes_until_schedule': 45,
    });
    expect(event.toAnalyticsParameters(platform: 'ios', appVersion: '1.2.3'), {
      'schema_version': 1,
      'workflow': 'schedule',
      'result': 'success',
      'platform': 'ios',
      'app_version': '1.2.3',
      'preparation_mode': 'custom',
      'preparation_step_count': 3,
      'minutes_until_schedule': 45,
    });
  });

  test('catalog rejects unknown product usage events', () {
    expect(
      () => ProductUsageEvent.fromCatalog(
        name: 'raw_button_clicked',
        result: ProductUsageResult.success,
      ),
      throwsA(isA<ProductUsageEventCatalogException>()),
    );
  });

  test('catalog rejects parameters that are not allowlisted for the event', () {
    expect(
      () => ProductUsageEvent.fromCatalog(
        name: 'schedule_created',
        result: ProductUsageResult.success,
        parameters: {'auth_provider': 'google'},
      ),
      throwsA(isA<ProductUsageEventCatalogException>()),
    );
  });

  test('catalog rejects forbidden privacy-sensitive fields', () {
    expect(
      () => ProductUsageEvent.fromCatalog(
        name: 'schedule_created',
        result: ProductUsageResult.success,
        parameters: {'schedule_note': 'leave early'},
      ),
      throwsA(isA<ProductUsageEventCatalogException>()),
    );
  });

  test('catalog rejects arbitrary nested map parameter values', () {
    expect(
      () => ProductUsageEvent.fromCatalog(
        name: 'schedule_created',
        result: ProductUsageResult.success,
        parameters: {
          'preparation_mode': {'raw': 'custom'},
        },
      ),
      throwsA(isA<ProductUsageEventCatalogException>()),
    );
  });

  test('catalog matches the documented first-release events', () {
    final documentedCatalog = _documentedEventCatalog();
    final codeCatalog = {
      for (final event in ProductUsageEventCatalog.firstReleaseEvents)
        event.name: event.allowedParameterNames.toList()..sort(),
    };

    expect(codeCatalog, documentedCatalog);
  });
}

Map<String, List<String>> _documentedEventCatalog() {
  final catalog = <String, List<String>>{};
  final rows = File(
    'docs/Analytics-Event-Catalog.md',
  ).readAsLinesSync().where((line) => line.startsWith('| `'));

  for (final row in rows) {
    final cells = row.split('|').map((cell) => cell.trim()).toList();
    if (cells.length < 6) continue;
    final eventName = _backtickValues(cells[1]).single;
    final parameterNames = _backtickValues(cells[4]).toList()..sort();
    catalog[eventName] = parameterNames;
  }
  return catalog;
}

Iterable<String> _backtickValues(String markdown) {
  return RegExp(
    r'`([^`]+)`',
  ).allMatches(markdown).map((match) => match.group(1)!);
}
