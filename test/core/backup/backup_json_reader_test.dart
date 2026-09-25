import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_json_reader.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';

class JsonTestSink implements BackupJsonSink {
  final rows = <Map<String, Object?>>[];
  final keys = <String>{};
  @override
  int writeNode(int? parent, String? key, String kind, Object? value) {
    if (parent != null && !keys.add('$parent/$key')) BackupLimits.invalid();
    rows.add({'parent': parent, 'key': key, 'kind': kind, 'value': value});
    return rows.length;
  }
}

Future<JsonTestSink> read(
  String value, {
  int chunk = 1,
  BackupBudget? budget,
}) async {
  final bytes = utf8.encode(value);
  Stream<List<int>> source() async* {
    for (var i = 0; i < bytes.length; i += chunk) {
      yield bytes.sublist(i, (i + chunk).clamp(0, bytes.length));
    }
  }

  final sink = JsonTestSink();
  await BackupJsonReader(sink, budget ?? BackupBudget()).read(source());
  return sink;
}

void main() {
  test(
    'UTF-8, escaped surrogate pair and original key order survive split reads',
    () async {
      final sink = await read(
        r'{"z":"한글😀","a":"\ud83d\ude00","n":[true,null,-1,1.25]}',
      );
      expect(
        sink.rows.where((r) => r['kind'] == 'string').map((r) => r['value']),
        ['한글😀', '😀'],
      );
      expect(sink.rows[1]['key'], 'z');
      expect(sink.rows[2]['key'], 'a');
    },
  );
  for (final source in [
    r'{"a":1,"\u0061":2}',
    '{"a":1,}',
    '[1,]',
    '[1 2]',
    '{"a" 1}',
    '1 2',
    '01',
    r'"\ud800"',
    r'"\udc00"',
    '"\n"',
    '{',
    '',
  ]) {
    test('reject malformed or duplicate JSON: ${jsonEncode(source)}', () async {
      await expectLater(read(source), throwsA(isA<BackupProcessingFailure>()));
    });
  }
  test(
    'maximum decoded string is accepted even when split inside escapes',
    () async {
      final sink = await read(
        '"${'a' * BackupLimits.stringBytes}"',
        chunk: 4093,
      );
      expect(
        (sink.rows.single['value'] as String).length,
        BackupLimits.stringBytes,
      );
    },
  );
  test(
    'giant scalar is refused before a sink can allocate its value',
    () async {
      final sink = JsonTestSink();
      final budget = BackupBudget();
      final reader = BackupJsonReader(sink, budget);
      await expectLater(
        reader.read(
          Stream.value(
            utf8.encode('"${'a' * (BackupLimits.stringBytes + 1)}"'),
          ),
        ),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'kind',
            BackupFailureKind.resourceLimit,
          ),
        ),
      );
      expect(sink.rows, isEmpty);
      expect(budget.largestTrackedBufferBytes, BackupLimits.stringBytes);
    },
  );
  test('key bound differs from string bound', () async {
    await expectLater(
      read('{"${'a' * 513}":0}', chunk: 128),
      throwsA(isA<BackupProcessingFailure>()),
    );
  });
  test('container depth has exact 32 boundary', () async {
    await read('${'[' * 32}0${']' * 32}');
    await expectLater(
      read('${'[' * 33}0${']' * 33}'),
      throwsA(isA<BackupProcessingFailure>()),
    );
  });
  test('cancellation is preserved and not relabelled malformed JSON', () async {
    final owner = BackupProcessingOwner();
    final lease = owner.acquire();
    lease.requestCancellation();
    await expectLater(
      read('{}', budget: BackupBudget(lease: lease)),
      throwsA(
        isA<BackupProcessingFailure>().having(
          (e) => e.kind,
          'kind',
          BackupFailureKind.userCancelled,
        ),
      ),
    );
    lease.release();
  });
}
