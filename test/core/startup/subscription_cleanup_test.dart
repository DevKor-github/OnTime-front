import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/startup/subscription_cleanup.dart';

void main() {
  test(
    'retired real subscription cancellation remains owned until completion',
    () async {
      final release = Completer<void>();
      var cancellations = 0;
      final stream = StreamController<void>(
        onCancel: () {
          cancellations++;
          return release.future;
        },
      );
      final owner = SubscriptionCleanup();
      owner.retire(stream.stream.listen((_) {}));
      var closed = false;
      final closing = owner.close().then((_) => closed = true);
      await pumpEventQueue();
      expect(closed, false);
      expect(cancellations, 1);
      release.complete();
      await closing;
      await owner.close();
      expect(cancellations, 1);
      await stream.close();
    },
  );

  test(
    'awaited retirement and owner close observe the same cancel Future',
    () async {
      final release = Completer<void>();
      var cancellations = 0;
      final stream = StreamController<void>(
        onCancel: () {
          cancellations++;
          return release.future;
        },
      );
      final owner = SubscriptionCleanup();
      final retired = owner.cancelAndWait(stream.stream.listen((_) {}));
      final closing = owner.close();
      await pumpEventQueue();
      expect(cancellations, 1);
      release.complete();
      await Future.wait([retired, closing]);
      await stream.close();
    },
  );
}
