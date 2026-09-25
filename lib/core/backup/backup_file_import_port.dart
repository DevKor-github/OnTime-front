import 'dart:async';
import 'package:flutter/services.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/ports/backup_file_import_port.dart';
import 'backup_limits.dart';

class NativeBackupFileImportPort implements BackupFileImportPort {
  const NativeBackupFileImportPort();
  static const channel = MethodChannel('ontime/backup_import');

  @override
  Future<BackupImportSource?> select({BackupProcessingLease? lease}) async {
    final handle = await _native<String>('begin');
    if (handle == null || handle.isEmpty) _io();
    final source = _NativeImportSource(handle, lease);
    lease?.cancellationRequested.then((_) async {
      // Retain the same close flight; openRead/select will observe its result.
      try {
        await source.close();
      } catch (_) {
        /* owner retries actual cleanup */
      }
    });
    try {
      lease?.check();
      final reply = await _native<Map<Object?, Object?>>('pick', {
        'handle': handle,
      });
      lease?.check();
      if (reply == null) {
        await source.close();
        return null;
      }
      final size = reply['length'];
      if (size != null && (size is! int || size < 0)) _io();
      source._declaredLength = size as int?;
      if (size is int && size > BackupLimits.cipherBytes) {
        BackupLimits.exceeded('cipherBytes');
      }
      return source;
    } catch (original) {
      try {
        await source.close();
      } catch (cleanup) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
      rethrow;
    }
  }
}

Future<T?> _native<T>(String method, [Map<String, Object?>? arguments]) async {
  try {
    return await NativeBackupFileImportPort.channel.invokeMethod<T>(
      method,
      arguments,
    );
  } on PlatformException catch (e) {
    throw BackupProcessingFailure(switch (e.code) {
      'import_limit' => BackupFailureKind.resourceLimit,
      'import_cancelled' => BackupFailureKind.userCancelled,
      _ => BackupFailureKind.inputOutput,
    }, e.code == 'import_limit' ? 'cipherBytes' : null);
  }
}

Never _io() =>
    throw const BackupProcessingFailure(BackupFailureKind.inputOutput);

class _NativeImportSource implements BackupImportSource {
  _NativeImportSource(this.handle, this.lease);
  final String handle;
  final BackupProcessingLease? lease;
  int? _declaredLength;
  bool _opened = false;
  bool _closed = false;
  bool _cleanupRetained = false;
  Future<void>? _closing;
  @override
  int? get declaredLength => _declaredLength;

  @override
  Stream<Uint8List> openRead() async* {
    if (_opened || _closed) _io();
    _opened = true;
    var consumed = 0;
    Object? original;
    try {
      while (true) {
        lease?.check();
        // One-byte EOF probe at the cap; no cap+1 allocation.
        final request = (BackupLimits.cipherBytes - consumed + 1).clamp(
          1,
          65536,
        );
        final reply = await _native<Map<Object?, Object?>>('read', {
          'handle': handle,
          'maxBytes': request,
        });
        lease?.check();
        if (reply == null ||
            reply['bytes'] is! Uint8List ||
            reply['eof'] is! bool) {
          _io();
        }
        final bytes = reply['bytes'] as Uint8List;
        final eof = reply['eof'] as bool;
        if (bytes.length > request) _io();
        if (bytes.length > BackupLimits.cipherBytes - consumed) {
          BackupLimits.exceeded('cipherBytes');
        }
        consumed += bytes.length;
        if (eof) {
          if (bytes.isNotEmpty) _io();
          break;
        }
        if (bytes.isEmpty) _io();
        yield bytes;
      }
    } catch (error) {
      original = error;
      rethrow;
    } finally {
      try {
        await close();
      } catch (cleanup) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
    }
  }

  @override
  Future<void> close() =>
      _closing ??= _close().whenComplete(() => _closing = null);
  Future<void> _close() async {
    if (_closed) return;
    try {
      final acknowledged = await _native<bool>('close', {'handle': handle});
      if (acknowledged != true) _io();
      _closed = true;
    } catch (_) {
      if (!_cleanupRetained && lease != null) {
        _cleanupRetained = true;
        lease!.retainCleanup(close);
      }
      rethrow;
    }
  }
}
