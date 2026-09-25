import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/core/database/bootstrap_privacy_boundary.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/domain/entities/preparation_snapshot_validation.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/domain/repositories/schedule_repository.dart';
import 'package:on_time_front/core/services/notification_service.dart';

/// Rewrites app-owned projections before any session is consumed. A failed
/// cleanup never sets a success marker; the next startup repeats the work.
@Singleton()
class RuntimePrivacyMigration {
  RuntimePrivacyMigration(
    this.schedules,
    this.preparations,
    this.snapshots,
    this.registry, {
    @ignoreParam Future<void> Function()? cleanPlatform,
    @ignoreParam AlarmOperationCoordinator? operations,
    @ignoreParam DateTime Function()? now,
  }) : _cleanPlatform = cleanPlatform,
       _now = now ?? DateTime.now,
       _operations = operations ?? AlarmOperationCoordinator.shared;
  final DateTime Function() _now;
  final AlarmOperationCoordinator _operations;
  final Future<void> Function()? _cleanPlatform;
  final ScheduleRepository schedules;
  final PreparationLocalDataSource preparations;
  final PreparationWithTimeLocalDataSource snapshots;
  final AlarmRegistryLocalDataSource registry;
  static const _prefix = 'preparation_with_time_';
  static const _earlyPrefix = 'early_start_session_';
  static const _native = MethodChannel('on_time_front/native_alarm');

  Future<void> run() {
    final lease = _operations.capture();
    return _operations.run(lease, _run);
  }

  Future<void> _run() async {
    final evaluationNow = _now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs.getKeys().where((key) => key.startsWith(_prefix)).toList()) {
      final id = key.substring(_prefix.length);
      TimedPreparationSnapshotEntity? replacement;
      try {
        final stored = await snapshots.loadPreparation(id);
        final rawSchedule = await schedules.getScheduleById(id);
        final schedule =
            ScheduleWithPreparationEntity.fromScheduleAndPreparationEntity(
              rawSchedule,
              PreparationWithTimeEntity.fromPreparation(
                await preparations.getPreparationByScheduleId(id),
              ),
              timeResolution: ScheduleTimeResolver.resolve(
                rawSchedule,
                nowUtc: evaluationNow,
              ),
            );
        if (schedule.doneStatus == ScheduleDoneStatus.notEnded) {
          replacement = stored == null
              ? null
              : validatePreparationSnapshot(stored, schedule);
          replacement ??= TimedPreparationSnapshotEntity(
            preparation: schedule.preparation,
            savedAt: evaluationNow,
            scheduleFingerprint: schedule.cacheFingerprint,
            requiresConfirmation: true,
          );
        }
      } on ScheduleTimeUnresolved {
        // This row cannot authorize reconstructing a run. Remove only its
        // installed transient projection below; the encrypted facts remain.
        // Storage/read/cleanup failures are deliberately not caught here.
        replacement = null;
      } catch (error, stack) {
        // Drift's getSingle signals a missing schedule as StateError('No element').
        // Other errors can mean the encrypted DB became unavailable; do not
        // silently classify every record as orphan and enter the normal app.
        if (error is! StateError || error.message != 'No element') {
          await bootstrapWithPrivacyCleanup(
            bootstrap: () async {
              Error.throwWithStackTrace(error, stack);
            },
            cleanup: () =>
                _clearLegacyWithoutDatabase(cleanupPlatform: _cleanPlatform),
          );
        }
      }
      if (replacement == null) {
        await _remove(prefs, key);
        await _remove(prefs, '$_earlyPrefix$id');
      } else {
        // Storage failures propagate instead of pretending migration succeeded.
        await snapshots.savePreparation(id, replacement);
        if (replacement.requiresConfirmation) {
          await _remove(prefs, '$_earlyPrefix$id');
        }
      }
    }
    // Early-start without a validated progress record must not resurrect a run.
    for (final key
        in prefs
            .getKeys()
            .where((key) => key.startsWith(_earlyPrefix))
            .toList()) {
      if (!prefs.containsKey('$_prefix${key.substring(_earlyPrefix.length)}')) {
        await _remove(prefs, key);
      }
    }
    await registry.loadAll(); // Reader immediately rewrites legacy ownership.
    if (_cleanPlatform != null) {
      await _cleanPlatform();
    } else {
      await Future.wait([
        _native.invokeMethod<void>('sanitizeStoredLaunchPayload'),
        NotificationService.instance.removeLegacySchedulePayloads(),
      ]);
    }
  }

  static Future<void> clearLegacyWithoutDatabase({
    Future<void> Function()? cleanupPlatform,
  }) {
    final owner = AlarmOperationCoordinator.shared;
    return owner.run(
      owner.capture(),
      () => _clearLegacyWithoutDatabase(cleanupPlatform: cleanupPlatform),
    );
  }

  static Future<void> _clearLegacyWithoutDatabase({
    Future<void> Function()? cleanupPlatform,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // With no authoritative DB there is no way to validate arbitrary runtime
    // fields (including events). Drop only owned transient state, never DB/key.
    for (final key
        in prefs
            .getKeys()
            .where(
              (key) => key.startsWith(_prefix) || key.startsWith(_earlyPrefix),
            )
            .toList()) {
      await _remove(prefs, key);
    }
    await AlarmRegistryLocalDataSourceImpl().loadAll();
    if (cleanupPlatform != null) {
      await cleanupPlatform();
    } else {
      await Future.wait([
        _native.invokeMethod<void>('sanitizeStoredLaunchPayload'),
        NotificationService.instance.removeLegacySchedulePayloads(),
      ]);
    }
  }

  static Future<void> _remove(SharedPreferences prefs, String key) async {
    if (prefs.containsKey(key) && !await prefs.remove(key)) {
      throw StateError('Legacy runtime cleanup failed');
    }
  }
}
