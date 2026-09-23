import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';

void main() {
  test(
    'rejects competing operations instead of queueing destructive work',
    () async {
      final gate = LocalDataOperationGate();
      final pending = Completer<void>();
      final first = gate.run(() => pending.future);
      var invoked = false;
      await expectLater(
        gate.run(() async {
          invoked = true;
        }, replacesData: true),
        throwsA(isA<LocalDataOperationBusy>()),
      );
      expect(invoked, false);
      expect(gate.generation, 0);
      pending.complete();
      await first;
      await gate.run(() async {}, replacesData: true);
      expect(gate.generation, 1);
    },
  );

  test(
    'failure releases lease; invalidated database cannot be reused',
    () async {
      final gate = LocalDataOperationGate();
      await expectLater(
        gate.run(() async => throw StateError('failure')),
        throwsStateError,
      );
      await gate.run(() async {});
      gate.invalidate();
      await expectLater(
        gate.run(() async {}),
        throwsA(isA<LocalDataUnavailable>()),
      );
    },
  );
}
