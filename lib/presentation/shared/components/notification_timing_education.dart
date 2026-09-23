import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Installation-local education only. It never gates notification delivery.
class NotificationTimingEducation {
  static const preferenceKey = 'notification_timing_education_seen';
  static bool _presenting = false;

  static Future<bool> offerOnce(
    BuildContext context, {
    bool deliveryReconciled = false,
    bool Function()? isCurrent,
  }) async {
    if (_presenting) return false;
    _presenting = true;
    final generation = LocalDataOperationGate.shared.generation;
    final route = ModalRoute.of(context);
    bool canPresent() =>
        context.mounted &&
        generation == LocalDataOperationGate.shared.generation &&
        (isCurrent?.call() ?? route?.isCurrent ?? true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(preferenceKey) == true) return false;
      final service = getIt<FallbackAlarmNotificationService>();
      final timing = await service.checkExactTimingPermission();
      if (timing == AlarmPermissionState.unsupported) return false;
      final settings = await getIt<AlarmRepository>().getAlarmSettings();
      if (!settings.alarmsEnabled ||
          await service.checkPermission() != AlarmPermissionState.granted) {
        return false;
      }
      if (timing == AlarmPermissionState.granted) {
        if (!canPresent()) return false;
        await prefs.setBool(preferenceKey, true);
        return false;
      }
      if (!canPresent()) return false;
      // Arm approximate delivery before offering the optional improvement.
      if (!deliveryReconciled) await getIt<ReconcileAlarmsUseCase>()();
      if (!context.mounted || !canPresent()) return false;
      final l10n = AppLocalizations.of(context)!;
      final choiceFuture = showTwoActionDialog(
        context,
        config: TwoActionDialogConfig(
          title: l10n.notificationTimingEducationTitle,
          description: l10n.notificationTimingEducationDescription,
          secondaryAction: DialogActionConfig(label: l10n.doItLater),
          primaryAction: DialogActionConfig(
            label: l10n.openSettings,
            variant: ModalWideButtonVariant.primary,
          ),
        ),
      );
      // The dialog was synchronously presented after the final route check.
      // Do not consume the marker while asynchronous eligibility is pending.
      await prefs.setBool(preferenceKey, true).catchError((_) => false);
      final choice = await choiceFuture;
      if (choice != DialogActionResult.primary || !canPresent()) {
        return false;
      }
      await service.requestExactTimingPermission();
      await getIt<ReconcileAlarmsUseCase>()();
      return true;
    } catch (_) {
      // Optional education must not interrupt startup or change the ON setting.
      return false;
    } finally {
      _presenting = false;
    }
  }
}
