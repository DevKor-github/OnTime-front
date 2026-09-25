import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controls timers while allowing SDK futures created outside this zone to settle.
final class FakeClock {
  FakeClock(this._clock, this._outerZone);
  final FakeAsync _clock;
  final Zone _outerZone;

  Future<void> pump([Duration duration = Duration.zero]) async {
    _clock.flushMicrotasks();
    _clock.elapse(duration);
    await _outerZone.run(() => Future<void>.delayed(Duration.zero));
    _clock.flushMicrotasks();
  }

  Future<void> complete(Future<dynamic>? operation) async {
    if (operation != null) await operation;
  }
}

void fakeClockTest(String description, Future<void> Function(FakeClock) body) {
  test(description, () async {
    final clock = FakeAsync();
    final outerZone = Zone.current;
    var completed = false;
    Object? failure;
    StackTrace? failureStack;
    clock.run((_) {
      body(FakeClock(clock, outerZone)).then(
        (_) {
          completed = true;
        },
        onError: (Object error, StackTrace stack) {
          completed = true;
          failure = error;
          failureStack = stack;
        },
      );
    });
    // SDK cancellation may return an already-created future whose completion
    // uses its original zone. Yield to that zone without advancing fake time.
    for (var turn = 0; !completed && turn < 1000; turn++) {
      clock.flushMicrotasks();
      await Future<void>.delayed(Duration.zero);
    }
    clock.flushMicrotasks();
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    expect(
      completed,
      isTrue,
      reason: 'Test did not settle within 1000 event-loop turns.',
    );
    expect(
      clock.pendingTimers,
      isEmpty,
      reason: 'Every test must retire its timer owners.',
    );
  });
}
