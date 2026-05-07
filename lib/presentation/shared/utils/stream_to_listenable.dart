import 'dart:async';

import 'package:flutter/foundation.dart';

class StreamToListenable extends ChangeNotifier {
  late final List<StreamSubscription<dynamic>> subscriptions;

  StreamToListenable(List<Stream<dynamic>> streams) {
    subscriptions = [];
    for (final e in streams) {
      final s = e.asBroadcastStream().listen(_tt);
      subscriptions.add(s);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final e in subscriptions) {
      e.cancel();
    }
    super.dispose();
  }

  void _tt(Object? event) => notifyListeners();
}
