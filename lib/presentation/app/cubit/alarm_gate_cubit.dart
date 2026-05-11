import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
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
  }) : _alarmSchedulerService =
           alarmSchedulerService ?? getIt.get<AlarmSchedulerService>(),
       _alarmRepository = alarmRepository ?? getIt.get<AlarmRepository>(),
       _reconcileAlarmsUseCase =
           reconcileAlarmsUseCase ?? getIt.get<ReconcileAlarmsUseCase>(),
       _cancelAllAlarmsUseCase =
           cancelAllAlarmsUseCase ?? getIt.get<CancelAllAlarmsUseCase>(),
       super(const AlarmGateState.initial());

  static const String _dismissedKey = 'alarm_prompt_dismissed';
  static const String _logTag = '[AlarmGate]';

  final AlarmSchedulerService _alarmSchedulerService;
  final AlarmRepository _alarmRepository;
  final ReconcileAlarmsUseCase _reconcileAlarmsUseCase;
  final CancelAllAlarmsUseCase _cancelAllAlarmsUseCase;

  Future<void> refreshPermission({
    bool disableAlarmsWhenPermissionMissing = false,
    bool enableAlarmsOnGrant = false,
  }) async {
    final permission = await _alarmSchedulerService.checkPermission();
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

    if (disableAlarmsWhenPermissionMissing) {
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
    final permission = await _alarmSchedulerService.requestPermission();
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

    await _disableAlarmsBestEffort();
    emit(const AlarmGateState.required());
    return permission;
  }

  Future<void> dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    await _disableAlarmsBestEffort();
    emit(const AlarmGateState.dismissed());
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
