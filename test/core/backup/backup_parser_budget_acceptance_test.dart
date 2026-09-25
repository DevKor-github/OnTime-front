import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_json_reader.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

void main() {
  test(
    'T03 C09 exact remaining work admits a document and next byte pass cannot reset it',
    () async {
      final budget = BackupBudget()..visit(BackupLimits.work - 3);
      final sink = _Sink();
      await BackupJsonReader(
        sink,
        budget,
      ).read(Stream.value(utf8.encode('[0,1]')));
      expect(sink.nodes, 3);
      expect(budget.work, BackupLimits.work);
      final nextSink = _Sink();
      await expectLater(
        BackupJsonReader(
          nextSink,
          budget.bytePass(),
        ).read(Stream.value(utf8.encode('0'))),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.limit,
            'limit',
            'work',
          ),
        ),
      );
      expect(nextSink.nodes, 0);
      expect(budget.work, BackupLimits.work);
    },
  );

  test(
    'T03 C09 unknown JSON nodes beyond remaining work never reach the storage sink',
    () async {
      final budget = BackupBudget()..visit(BackupLimits.work - 3);
      final sink = _Sink();
      await expectLater(
        BackupJsonReader(
          sink,
          budget,
        ).read(Stream.value(utf8.encode('[0,1,2]'))),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.limit,
            'limit',
            'work',
          ),
        ),
      );
      expect(sink.nodes, 3);
      expect(budget.work, BackupLimits.work);
    },
  );

  test(
    'T03 C09 oversized numeric token is bounded before parsing or storage',
    () async {
      final sink = _Sink();
      final budget = BackupBudget();
      Stream<List<int>> input() async* {
        for (var at = 0; at < BackupLimits.stringBytes; at += 1024) {
          yield List.filled(1024, 49);
        }
        yield [49];
      }

      await expectLater(
        BackupJsonReader(sink, budget).read(input()),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.limit,
            'limit',
            'token',
          ),
        ),
      );
      expect(sink.nodes, 0);
    },
  );
}

class _Sink implements BackupJsonSink {
  int nodes = 0;
  @override
  int writeNode(int? parent, String? key, String kind, Object? scalar) =>
      ++nodes;
}
