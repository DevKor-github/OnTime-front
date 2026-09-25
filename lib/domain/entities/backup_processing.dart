import 'dart:async';
import 'backup_operation.dart';

/// A reason safe to render without exposing file contents or platform paths.
enum BackupFailureKind {
  userCancelled,
  resourceLimit,
  unsupportedRepresentation,
  authentication,
  dataInvariant,
  timeZoneChoiceRequired,
  inputOutput,
}

/// FormatException compatibility is retained for existing small-input callers;
/// product UI uses [kind], never the platform cause or raw message.
class BackupProcessingFailure extends FormatException {
  const BackupProcessingFailure(this.kind, [this.limit])
    : super('Backup processing could not complete');
  final BackupFailureKind kind;
  final String? limit;
}

enum BackupProcessingPhase {
  reading,
  validating,
  encrypting,
  choosingDestination,
  preview,
  applying,
  cancelling,
  cleanupPending,
}

/// One installation-process backup resource lease, not a DB writer gate. The
/// candidate inherits the same lease so opening previews cannot accumulate KDFs
/// or encrypted stores. A service, not a widget, owns terminal cleanup.
class BackupProcessingOwner {
  static final shared = BackupProcessingOwner();
  BackupProcessingLease? _active;
  final _changes = StreamController<BackupProcessingPhase?>.broadcast(
    sync: true,
  );
  Stream<BackupProcessingPhase?> get changes => _changes.stream;
  BackupProcessingLease? get active => _active;

  BackupProcessingLease acquire() {
    if (_active != null) {
      throw const DataOperationException(DataOperationFailure.busy);
    }
    final lease = BackupProcessingLease._(this);
    _active = lease;
    _changes.add(lease.phase);
    return lease;
  }

  void requestCancellation() => _active?.requestCancellation();
  Future<void> retryCleanup() async => _active?.retryCleanup();
}

class BackupProcessingLease {
  BackupProcessingLease._(this._owner);
  final BackupProcessingOwner _owner;
  BackupProcessingPhase phase = BackupProcessingPhase.reading;
  bool _cancelled = false;
  final _cancellation = Completer<void>();
  Future<void> get cancellationRequested => _cancellation.future;
  bool _released = false;
  bool cancellationAllowed = true;
  final _cleanup = <Future<void> Function()>[];
  var _operations = 0;
  Completer<void>? _idle;
  bool _releaseRequested = false;

  void beginOperation() {
    if (_released) return;
    if (_operations++ == 0) _idle = Completer<void>();
  }

  void endOperation() {
    if (_operations == 0) return;
    if (--_operations == 0) {
      _idle?.complete();
      _idle = null;
      if (_releaseRequested && _cleanup.isEmpty) release();
    }
  }

  Future<void>? _cleanupFlight;

  void update(BackupProcessingPhase value) {
    if (_released) return;
    phase = _cancelled && cancellationAllowed
        ? BackupProcessingPhase.cancelling
        : value;
    _owner._changes.add(phase);
  }

  void requestCancellation() {
    if (_released || !cancellationAllowed) return;
    _cancelled = true;
    if (!_cancellation.isCompleted) _cancellation.complete();
    update(BackupProcessingPhase.cancelling);
  }

  void check() {
    if (_cancelled) {
      throw const BackupProcessingFailure(BackupFailureKind.userCancelled);
    }
  }

  void retainCleanup(Future<void> Function() cleanup) {
    if (_released) throw StateError('Cannot abandon cleanup after release');
    _cleanup.add(cleanup);
    cancellationAllowed = false;
    update(BackupProcessingPhase.cleanupPending);
  }

  Future<void> retryCleanup() => _cleanupFlight ??= _retryCleanup()
      .whenComplete(() => _cleanupFlight = null);

  Future<void> _retryCleanup() async {
    // The operation may still be closing a provider or registering another
    // failed owner. A retry cannot release its lease before that work returns.
    while (_operations != 0) {
      await _idle!.future;
    }
    Object? firstFailure;
    final attempted = <Future<void> Function()>{};
    while (true) {
      final remaining = _cleanup.where((item) => !attempted.contains(item));
      if (remaining.isEmpty) break;
      final next = remaining.first;
      attempted.add(next);
      try {
        await next();
        _cleanup.remove(next);
      } catch (error) {
        firstFailure ??= error;
      }
      while (_operations != 0) {
        await _idle!.future;
      }
    }
    if (firstFailure != null) throw firstFailure;
    if (_cleanup.isEmpty) release();
  }

  /// Only call after every owned reader/native operation/store is terminal.
  void release() {
    if (_released) return;
    if (_cleanup.isNotEmpty) throw StateError('Cleanup is still owned');
    if (_operations != 0) {
      _releaseRequested = true;
      return;
    }
    _released = true;
    if (identical(_owner._active, this)) {
      _owner._active = null;
      _owner._changes.add(null);
    }
  }
}

/// Cleanup remains actionable without erasing the original rejection/cancel.
class BackupProcessingCleanupFailure implements Exception {
  const BackupProcessingCleanupFailure({
    this.originalError,
    required this.cleanupError,
  });
  final Object? originalError;
  final Object cleanupError;
}
