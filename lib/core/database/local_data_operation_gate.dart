import 'package:flutter/foundation.dart';

/// Serializes operations that snapshot or replace the current installation.
/// Ordinary edits remain available while a backup destination picker is open.
final class LocalDataOperationGate extends ChangeNotifier {
  static final shared = LocalDataOperationGate();

  bool _busy = false;
  bool _unavailable = false;
  bool _replacingData = false;
  int _generation = 0;

  int get generation => _generation;
  bool get isReplacingData => _replacingData;
  bool get isInvalidated => _unavailable;
  bool get isAvailable => !_busy && !_unavailable;

  Future<T> run<T>(
    Future<T> Function() action, {
    bool replacesData = false,
  }) async {
    if (_busy) throw const LocalDataOperationBusy();
    if (_unavailable) throw const LocalDataUnavailable();
    _busy = true;
    _replacingData = replacesData;
    if (replacesData) _generation++;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      _replacingData = false;
      notifyListeners();
    }
  }

  /// Reset intent makes the installation unavailable until restart, including
  /// when cancellation fails before the old database can safely be closed.
  void invalidate() {
    _generation++;
    _unavailable = true;
    notifyListeners();
  }
}

final class LocalDataOperationBusy implements Exception {
  const LocalDataOperationBusy();
  @override
  String toString() => '다른 데이터 작업이 진행 중입니다. 완료 후 다시 시도해주세요.';
}

final class LocalDataUnavailable implements Exception {
  const LocalDataUnavailable();
  @override
  String toString() => '로컬 데이터가 변경되었습니다. 앱을 다시 열어주세요.';
}
