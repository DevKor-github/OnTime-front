import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_json_reader.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

void main() {
  for (final entry in [
    ('schedules', BackupLimits.schedules, 'schedules'),
    ('templates', BackupLimits.records, 'records'),
  ]) {
    test(
      'actual ${entry.$2} ${entry.$3} cap admits input entries before disk allocation including duplicate IDs',
      () async {
        final sink = _Counter();
        final budget = BackupBudget();
        Stream<List<int>> input() async* {
          yield utf8.encode('{"${entry.$1}":[');
          for (var i = 0; i <= entry.$2; i++) {
            yield utf8.encode('${i == 0 ? '' : ','}{"id":"same"}');
          }
          yield utf8.encode(']}');
        }

        await expectLater(
          BackupJsonReader(sink, budget, portableRecords: true).read(input()),
          throwsA(
            isA<BackupProcessingFailure>().having(
              (e) => e.limit,
              'limit',
              entry.$3,
            ),
          ),
        );
        expect(budget.records, entry.$2);
        // root+array and exactly two nodes per admitted record; rejected record
        // has not reached the sink even though its duplicate identity is unknown.
        expect(sink.nodes, 2 + 2 * entry.$2);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
  test(
    'original UTF8 identifier limit applies while reading token before value write',
    () async {
      final sink = _Counter();
      final budget = BackupBudget();
      await expectLater(
        BackupJsonReader(sink, budget, portableRecords: true).read(
          Stream.value(utf8.encode('{"schedules":[{"id":"${'a' * 513}"}]}')),
        ),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      expect(sink.nodes, 3);
    },
  );
  test('unknown fields still consume logical node work and depth', () async {
    final budget = BackupBudget();
    final sink = _Counter();
    await BackupJsonReader(
      sink,
      budget,
      portableRecords: true,
    ).read(Stream.value(utf8.encode('{"unknown":[1,2,3]}')));
    expect(budget.work, 5);
    expect(budget.records, 0);
  });
}

class _Counter implements BackupJsonSink {
  var nodes = 0;
  @override
  int writeNode(int? parent, String? key, String kind, Object? value) =>
      ++nodes;
}
