import 'package:on_time_front/core/database/local_reset_actions.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';
import 'package:on_time_front/core/services/alarm_registration_cleanup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/data/data_sources/alarm_registry_local_data_source.dart';
import 'package:on_time_front/data/repositories/alarm_registry_repository_impl.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';

/// Restore reuses only D03's app-owned delivery and launch cleanup. It never
/// creates a reset intent or invokes database/preferences/key/credential steps.
Future<void> cleanupRestoreDeliveries(
  AlarmOperationCoordinator owner, {
  DeviceLocalResetActions? actions,
  AlarmRegistrationCleanup? registrationCleanup,
}) => owner.cleanup(
  () => cleanupRestoreDeliveriesUnderOwner(
    owner,
    actions: actions,
    registrationCleanup: registrationCleanup,
  ),
);

/// For an existing replacement owner only; never enqueue recursively.
Future<void> cleanupRestoreDeliveriesUnderOwner(
  AlarmOperationCoordinator owner, {
  DeviceLocalResetActions? actions,
  AlarmRegistrationCleanup? registrationCleanup,
}) async {
  final target = actions ?? DeviceLocalResetActions();
  final cleanup =
      registrationCleanup ??
      AlarmRegistrationCleanup(
        AlarmRegistryRepositoryImpl(
          localDataSource: AlarmRegistryLocalDataSourceImpl(),
        ),
        AlarmSchedulerService(),
        FallbackAlarmNotificationServiceImpl(),
        owner,
      );
  // Await real old provider Futures, including returned failures. Global OS
  // absence can subsequently resolve uncertainty; a timeout cannot do so.
  await cleanup.cancelMatchingReport();
  await target.perform(ResetStep.deliveries);
  await target.perform(ResetStep.launch);
  var state = await owner.journal.read();
  if (state.reset != ResetPhase.none) throw const AlarmCleanupIncomplete();
  if (target.allProvidersConfirmedEmpty) {
    final registry = cleanup.registry;
    for (final entry in state.ownership.values.toList()) {
      await owner.confirmedCancelled(registry, entry.record);
    }
    await owner.replaceRecords(registry, []);
    if (registry is RecoverableAlarmOwnershipIntegrity) {
      await (registry as RecoverableAlarmOwnershipIntegrity)
          .clearResolvedOwnership();
    }
    state = await owner.journal.read();
    state.unknownOwnership = false;
    await owner.journal.save(state);
  }
  // Android cannot globally enumerate AlarmManager: known per-ID cancellations
  // suffice only when the independent journal has no unknown ownership.
  final remaining = await owner.loadRecords(cleanup.registry);
  state = await owner.journal.read();
  if (remaining.isNotEmpty ||
      state.ownership.isNotEmpty ||
      state.unknownOwnership) {
    throw const AlarmCleanupIncomplete();
  }
}
