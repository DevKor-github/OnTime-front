import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/ports/backup_file_export_port.dart';
import 'backup_limits.dart';
export 'package:on_time_front/domain/ports/backup_file_export_port.dart';

final class NativeBackupFileExportPort implements BackupFileExportPort {
  const NativeBackupFileExportPort();
  static const channel = MethodChannel('ontime/backup_export');

  @override
  Future<BackupFileExportReceipt> exportStream({
    required Stream<List<int>> encrypted,
    required String suggestedName,
    BackupProcessingLease? lease,
  }) async {
    final effectiveLease = lease ?? BackupProcessingOwner.shared.acquire();
    effectiveLease.beginOperation();
    try {
      return await _export(
        encrypted: encrypted,
        suggestedName: suggestedName,
        lease: effectiveLease,
      );
    } finally {
      if (lease == null &&
          effectiveLease.phase != BackupProcessingPhase.cleanupPending) {
        effectiveLease.release();
      }
      effectiveLease.endOperation();
    }
  }

  Future<BackupFileExportReceipt> _export({
    required Stream<List<int>> encrypted,
    required String suggestedName,
    required BackupProcessingLease lease,
  }) async {
    final handle = await _invoke<String>('begin', {
      'suggestedName': suggestedName,
    });
    if (handle == null || handle.isEmpty) throw const BackupFileExportFailure();
    final attempt = _NativeExportAttempt(handle);
    lease.cancellationRequested.then((_) async {
      try {
        await attempt.cancel();
      } catch (_) {
        /* Actual finally/owner retains retry. */
      }
    });
    Object? original;
    var saved = false;
    BackupFileExportReceipt? receipt;
    try {
      final digest = _DigestSink();
      final hash = sha256.startChunkedConversion(digest);
      var length = 0;
      var sequence = 0;
      await for (final chunk in encrypted) {
        lease.check();
        // Crypto frames and channel messages have different boundaries. Only
        // one <=64KiB message is in flight, with acknowledgement before reuse.
        for (var at = 0; at < chunk.length; at += 65536) {
          final end = (at + 65536).clamp(0, chunk.length);
          final amount = end - at;
          if (amount > BackupLimits.cipherBytes - length) {
            BackupLimits.exceeded('cipherBytes');
          }
          final bytes = Uint8List.fromList(chunk.sublist(at, end));
          final ack = await _invoke<bool>('append', {
            'handle': handle,
            'sequence': sequence,
            'bytes': bytes,
          });
          if (ack != true) throw const BackupFileExportFailure();
          length += bytes.length;
          hash.add(bytes);
          sequence++;
          lease.check();
        }
      }
      hash.close();
      lease.check();
      if (length == 0) throw const BackupFileExportFailure();
      final seal = await _invoke<bool>('seal', {
        'handle': handle,
        'length': length,
        'sha256': digest.value!.toString(),
      });
      if (seal != true) throw const BackupFileExportFailure();
      lease.check();
      lease.update(BackupProcessingPhase.choosingDestination);
      final result = await _invoke<Map<Object?, Object?>>('export', {
        'handle': handle,
      });
      attempt.observe(result);
      saved = attempt.outcome == 'saved';
      if (saved) {
        receipt = BackupFileExportReceipt.saved;
      } else if (attempt.outcome == 'cancelled') {
        receipt = BackupFileExportReceipt.cancelled;
      } else {
        throw const BackupFileExportFailure();
      }
    } catch (error) {
      original = error;
    }
    // Cancellation may race the OS save acknowledgement. Its authoritative
    // saved receipt survives cancellation and all later temporary cleanup errors.
    try {
      await attempt.cancel();
      saved = saved || attempt.outcome == 'saved';
      if (attempt.cleanupUnconfirmed) {
        lease.retainCleanup(() async {
          await attempt.cancel();
          if (attempt.cleanupUnconfirmed) throw const BackupFileExportFailure();
        });
        if (!saved) throw const BackupFileExportFailure();
      }
    } catch (cleanup) {
      lease.retainCleanup(() async {
        await attempt.cancel();
        if (attempt.cleanupUnconfirmed) throw const BackupFileExportFailure();
      });
      if (!saved) {
        throw BackupProcessingCleanupFailure(
          originalError: original,
          cleanupError: cleanup,
        );
      }
    }
    if (saved) return BackupFileExportReceipt.saved;
    if (original != null) {
      Error.throwWithStackTrace(original, StackTrace.current);
    }
    return receipt ?? BackupFileExportReceipt.cancelled;
  }
}

Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
  try {
    return await NativeBackupFileExportPort.channel.invokeMethod<T>(
      method,
      args,
    );
  } on PlatformException catch (error) {
    throw BackupProcessingFailure(switch (error.code) {
      'export_limit' => BackupFailureKind.resourceLimit,
      'export_cancelled' => BackupFailureKind.userCancelled,
      _ => BackupFailureKind.inputOutput,
    }, error.code == 'export_limit' ? 'cipherBytes' : null);
  }
}

class _NativeExportAttempt {
  _NativeExportAttempt(this.handle);
  final String handle;
  String? outcome;
  bool cleanupUnconfirmed = true;
  Future<void>? _cancelFlight;
  void observe(Map<Object?, Object?>? result) {
    if (result == null ||
        !{'saved', 'cancelled', 'failed'}.contains(result['outcome']) ||
        result['cleanupUnconfirmed'] is! bool) {
      throw const BackupFileExportFailure();
    }
    if (outcome != 'saved') outcome = result['outcome'] as String;
    cleanupUnconfirmed = result['cleanupUnconfirmed'] as bool;
  }

  Future<void> cancel() =>
      _cancelFlight ??= _cancel().whenComplete(() => _cancelFlight = null);
  Future<void> _cancel() async {
    if (!cleanupUnconfirmed) return;
    observe(await _invoke<Map<Object?, Object?>>('cancel', {'handle': handle}));
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
