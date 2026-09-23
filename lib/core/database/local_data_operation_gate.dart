/// Serializes operations that snapshot or replace the current installation.
/// Ordinary edits remain available while a backup destination picker is open.
final class LocalDataOperationGate {
  static final shared = LocalDataOperationGate();

  bool _busy = false;
  bool _unavailable = false;
  int _generation = 0;

  int get generation => _generation;

  Future<T> run<T>(
    Future<T> Function() action, {
    bool replacesData = false,
  }) async {
    if (_busy) throw const LocalDataOperationBusy();
    if (_unavailable) throw const LocalDataUnavailable();
    _busy = true;
    if (replacesData) _generation++;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  /// Reset closes the active database; it cannot be used again before restart.
  void invalidate() {
    _generation++;
    _unavailable = true;
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
