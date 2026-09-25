import 'dart:async';

/// Retired watches remain owned until their real cancel Future finishes.
final class SubscriptionCleanup {
  final _entries = <StreamSubscription<dynamic>, _Cancellation>{};
  void retire(StreamSubscription<dynamic>? subscription) {
    if (subscription == null) return;
    final entry = _entries.putIfAbsent(
      subscription,
      () => _Cancellation(subscription),
    );
    unawaited(
      entry.run().then((_) {
        if (entry.done && identical(_entries[subscription], entry)) {
          _entries.remove(subscription);
        }
      }),
    );
  }

  Future<void> cancelAndWait(StreamSubscription<dynamic>? subscription) async {
    if (subscription == null) return;
    final entry = _entries.putIfAbsent(
      subscription,
      () => _Cancellation(subscription),
    );
    await entry.run();
    if (!entry.done) throw StateError('Watch cleanup is incomplete');
    if (identical(_entries[subscription], entry)) _entries.remove(subscription);
  }

  Future<void> close() async {
    final entries = _entries.values.toList();
    await Future.wait(entries.map((entry) => entry.run()));
    _entries.removeWhere((_, entry) => entry.done);
    if (_entries.isNotEmpty) throw StateError('Watch cleanup is incomplete');
  }
}

final class _Cancellation {
  _Cancellation(this.subscription);
  final StreamSubscription<dynamic> subscription;
  bool done = false;
  Future<void>? _flight;
  Future<void> run() => done
      ? Future.value()
      : _flight ??= _run().whenComplete(() => _flight = null);
  Future<void> _run() async {
    try {
      await subscription.cancel();
      done = true;
    } catch (_) {
      /* Owner retains failed cancellation for explicit cleanup. */
    }
  }
}
