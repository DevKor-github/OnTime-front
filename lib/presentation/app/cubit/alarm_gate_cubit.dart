import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'alarm_gate_state.dart';

class AlarmGateCubit extends Cubit<AlarmGateState> {
  AlarmGateCubit({
    AlarmSchedulerService? alarmSchedulerService,
    AlarmRepository? alarmRepository,
    ReconcileAlarmsUseCase? reconcileAlarmsUseCase,
    CancelAllAlarmsUseCase? cancelAllAlarmsUseCase,
    FallbackAlarmNotificationService? fallbackAlarmNotificationService,
  }) : _alarmSchedulerService =
           alarmSchedulerService ?? getIt.get<AlarmSchedulerService>(),
       _alarmRepository = alarmRepository ?? getIt.get<AlarmRepository>(),
       _reconcileAlarmsUseCase =
           reconcileAlarmsUseCase ?? getIt.get<ReconcileAlarmsUseCase>(),
       _cancelAllAlarmsUseCase =
           cancelAllAlarmsUseCase ?? getIt.get<CancelAllAlarmsUseCase>(),
       _fallbackAlarmNotificationService =
           fallbackAlarmNotificationService ??
           getIt.get<FallbackAlarmNotificationService>(),
       super(const AlarmGateState.initial());

  static const String _dismissedKey = 'alarm_prompt_dismissed';
  static const String _logTag = '[AlarmGate]';

  final AlarmSchedulerService _alarmSchedulerService;
  final AlarmRepository _alarmRepository;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;
  final CancelAllAlarmsUseCase _cancelAllAlarmsUseCase;
  final FallbackAlarmNotificationService _fallbackAlarmNotificationService;

  Future<void> refreshPermission({
    bool disableAlarmsWhenPermissionMissing = false,
    bool enableAlarmsOnGrant = false,
  }) async {
    final capabilities = await _alarmSchedulerService.getCapabilities();
    final permission = await _checkEffectivePermission(capabilities);
    if (permission == AlarmPermissionState.unsupported) {
      emit(const AlarmGateState.unsupported());
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (permission == AlarmPermissionState.granted) {
      await prefs.remove(_dismissedKey);
      if (enableAlarmsOnGrant) {
        await _enableAlarmsBestEffort();
      }
      emit(const AlarmGateState.allowed());
      return;
    }

    if (disableAlarmsWhenPermissionMissing &&
        !await _hasGrantedFallbackPermission(capabilities)) {
      await _disableAlarmsBestEffort();
    }

    final isDismissed = prefs.getBool(_dismissedKey) ?? false;
    emit(
      isDismissed
          ? const AlarmGateState.dismissed()
          : const AlarmGateState.required(),
    );
  }

  Future<AlarmPermissionState> requestPermission() async {
    final capabilities = await _alarmSchedulerService.getCapabilities();
    final permission = await _requestEffectivePermission(capabilities);
    if (permission == AlarmPermissionState.unsupported) {
      emit(const AlarmGateState.unsupported());
      return permission;
    }

    if (permission == AlarmPermissionState.granted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dismissedKey);
      await _enableAlarmsBestEffort();
      emit(const AlarmGateState.allowed());
      return permission;
    }

    if (!await _hasGrantedFallbackPermission(capabilities)) {
      await _disableAlarmsBestEffort();
    }
    emit(const AlarmGateState.required());
    return permission;
  }

  Future<AlarmPermissionState> _checkEffectivePermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    final nativePermission = await _checkNativePermission(capabilities);
    if (nativePermission == AlarmPermissionState.granted) {
      return nativePermission;
    }

    if (nativePermission == AlarmPermissionState.unsupported) {
      return _checkFallbackPermission(capabilities);
    }
    return nativePermission;
  }

  Future<AlarmPermissionState> _requestEffectivePermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    final nativePermission = await _requestNativePermission(capabilities);
    if (nativePermission == AlarmPermissionState.granted) {
      return nativePermission;
    }

    if (nativePermission == AlarmPermissionState.unsupported) {
      return _requestFallbackPermission(capabilities);
    }
    final fallbackPermission = await _requestFallbackPermission(capabilities);
    if (fallbackPermission == AlarmPermissionState.granted) {
      return fallbackPermission;
    }
    return nativePermission;
  }

  Future<AlarmPermissionState> _checkNativePermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    if (!capabilities.supportsNativeAlarm ||
        capabilities.nativeAlarmProvider == AlarmProvider.none ||
        !nativeAlarmProviderAllowedByReleasePolicy(
          capabilities.nativeAlarmProvider,
        )) {
      return AlarmPermissionState.unsupported;
    }
    return _alarmSchedulerService.checkPermission();
  }

  Future<AlarmPermissionState> _requestNativePermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    if (!capabilities.supportsNativeAlarm ||
        capabilities.nativeAlarmProvider == AlarmProvider.none ||
        !nativeAlarmProviderAllowedByReleasePolicy(
          capabilities.nativeAlarmProvider,
        )) {
      return AlarmPermissionState.unsupported;
    }
    return _alarmSchedulerService.requestPermission();
  }

  Future<AlarmPermissionState> _checkFallbackPermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    if (capabilities.fallbackProvider != AlarmProvider.localNotification) {
      return AlarmPermissionState.unsupported;
    }
    return _fallbackAlarmNotificationService.checkPermission();
  }

  Future<AlarmPermissionState> _requestFallbackPermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    if (capabilities.fallbackProvider != AlarmProvider.localNotification) {
      return AlarmPermissionState.unsupported;
    }
    return _fallbackAlarmNotificationService.requestPermission();
  }

  Future<void> dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    final capabilities = await _alarmSchedulerService.getCapabilities();
    if (!await _hasGrantedFallbackPermission(capabilities)) {
      await _disableAlarmsBestEffort();
    }
    emit(const AlarmGateState.dismissed());
  }

  Future<bool> shouldUseAlarmLanguageForPrompt() async {
    final capabilities = await _alarmSchedulerService.getCapabilities();
    return capabilities.supportsNativeAlarm &&
        capabilities.nativeAlarmProvider == AlarmProvider.iosAlarmKit;
  }

  Future<bool> _hasGrantedFallbackPermission(
    AlarmSchedulerCapabilities capabilities,
  ) async {
    return await _checkFallbackPermission(capabilities) ==
        AlarmPermissionState.granted;
  }

  Future<void> _enableAlarmsBestEffort() async {
    try {
      await _alarmRepository.updateAlarmSettings(alarmsEnabled: true);
      await _reconcileAlarmsUseCase();
    } catch (error) {
      AppLogger.debug(
        '$_logTag enable alarms failed errorType=${error.runtimeType}',
      );
    }
  }

  Future<void> _disableAlarmsBestEffort() async {
    try {
      await _alarmRepository.updateAlarmSettings(alarmsEnabled: false);
      await _cancelAllAlarmsUseCase();
    } catch (error) {
      AppLogger.debug(
        '$_logTag disable alarms failed errorType=${error.runtimeType}',
      );
    }
  }
}
