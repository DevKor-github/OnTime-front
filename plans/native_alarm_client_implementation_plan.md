# Native Alarm Client Implementation Plan

## Goal

Replace the legacy fixed push reminder behavior with a client-owned alarm mirror for upcoming schedules.

The server remains the source of truth for schedules, preparation data, global alarm settings, current device registration, and diagnostic alarm status. The Flutter app owns local reconciliation, native alarm scheduling, fallback notification scheduling, local alarm registry persistence, permission UX, and launch routing.

## Context

- Backend contract is defined in `plans/backend_alarm_feature_spec.md`.
- Existing notification code lives in `lib/core/services/notification_service.dart` and should remain focused on FCM, foreground/background push handling, local notification display, and fallback notification support.
- Existing schedule state and timer behavior lives in `lib/presentation/app/bloc/schedule/schedule_bloc.dart`.
- Existing schedule start route is `/scheduleStart` in `lib/presentation/shared/router/go_router.dart`.
- Existing schedule entity computes `preparationStartTime` in `lib/domain/entities/schedule_with_preparation_entity.dart`.
- Current schedule data is server-backed through `ScheduleRepositoryImpl`, `ScheduleRemoteDataSource`, and related use cases.
- Root architecture follows clean layers: `core` for platform services, `data` for sources/models/repositories, `domain` for entities/repository contracts/use cases, and `presentation` for screens/blocs/widgets.

## Decisions

- Alarm fires 5 minutes before `preparationStartTime`.
- `preparationStartTime = scheduleTime - moveTime - scheduleSpareTime - totalPreparationTime`.
- Device-local wall-clock schedule time is accepted for v1.
- Global alarms default to enabled on the backend.
- The app keeps `alarmsEnabled=true` when permission is missing, reports `permissionNeeded`, and does not schedule until native or fallback permission is available.
- Reconciliation targets all not-ended schedules whose computed alarm time is in the next 7 days.
- The schedule query is padded: request schedules by `scheduleTime` for about 8 days, then filter by computed `alarmTime` for 7-day coverage.
- Do not schedule past alarms.
- Use true native alarms where available: Android `AlarmManager.setAlarmClock`, iOS 26+ AlarmKit.
- Use local notification fallback elsewhere when notification permission exists.
- Do not use Android inexact alarms if exact/native alarm permission is denied.
- Alarm tap opens `/scheduleStart` with `scheduleId` and `promptVariant: alarm`.
- Alarm firing/tapping does not start preparation automatically.
- Validate the schedule before showing start UI; alarm payload is only a hint.
- Introduce a separate alarm layer; keep `NotificationService` for FCM and fallback notifications.
- Use MethodChannel/native platform code for native alarms unless a package cleanly supports the exact Android and iOS requirements.
- Persist a local alarm registry keyed by `scheduleId`.
- Trigger reconciliation from auth/app lifecycle and schedule mutation boundaries, not screens directly.
- On logout or session invalidation, cancel native alarms, cancel fallback notifications, clear registry, and leave server schedules untouched.
- Cancel the pending schedule alarm when the user starts preparation early.
- Prioritize reconciliation unit tests before native platform tests.
- Mention future server-backed per-schedule alarm settings, but do not build per-schedule toggles in v1.

## Steps

1. Add alarm domain entities and enums.
   - Create entities for `AlarmSettings`, `AlarmDeviceInfo`, `ScheduledAlarmRecord`, `AlarmReconciliationResult`, `AlarmStatusReport`, `AlarmProvider`, `AlarmPermissionIssue`, and `AlarmFailureReason`.
   - Keep computed fields deterministic: `preparationStartTime`, `alarmTime`, and `scheduleFingerprint`.
   - Model provider states as `androidAlarmManager`, `iosAlarmKit`, `localNotification`, and `none`.

2. Add backend API models and data sources.
   - Add endpoints for:
     - `GET /users/me/alarm-settings`
     - `PATCH /users/me/alarm-settings`
     - `PUT /users/me/devices/current`
     - `DELETE /users/me/devices/current`
     - `GET /schedules/alarm-window`
     - `POST /users/me/alarm-status`
   - Update FCM token registration request to include `deviceId`.
   - Add JSON models for alarm settings, device registration, alarm-window schedules, preparation steps, status reports, and structured failures.
   - Keep remote data sources in `lib/data/data_sources/`, models in `lib/data/models/`, and domain contracts in `lib/domain/repositories/`.

3. Add local alarm registry persistence.
   - Persist registry records keyed by `scheduleId`.
   - Include `alarmTime`, `preparationStartTime`, `scheduleFingerprint`, native alarm id, fallback notification id, provider, schedule title, and minimal payload.
   - Use an existing local persistence style where possible. SharedPreferences is acceptable for a small registry; Drift is better if the registry grows or needs queryability.
   - Provide operations: load all, upsert, delete by schedule id, delete all, and replace after reconciliation.

4. Add platform alarm service interface.
   - Create `AlarmSchedulerService` in `lib/core/services/`.
   - Expose methods:
     - `getCapabilities()`
     - `checkPermission()`
     - `requestPermission()`
     - `scheduleNativeAlarm(record)`
     - `cancelNativeAlarm(record)`
     - `cancelAllNativeAlarms(records)`
   - Keep `NotificationService` available for fallback scheduled local notifications and tap routing.
   - Convert platform exceptions into typed Dart failures for reconciliation.

5. Add MethodChannel native alarm bridge.
   - Use a stable channel name such as `on_time_front/native_alarm`.
   - Dart-to-native calls should include `scheduleId`, `alarmTime`, `title`, `body`, and payload containing `type=schedule_alarm`, `scheduleId`, `alarmTime`, and `preparationStartTime`.
   - Native-to-Dart or launch-intent payload handling should route into the existing navigation service after app startup is ready.

6. Implement Android native alarm behavior.
   - Use `AlarmManager.setAlarmClock` for true alarm behavior.
   - Use stable request codes derived from persisted schedule ids or stored registry ids.
   - Build a `PendingIntent` that opens the Flutter app with the alarm payload.
   - Check exact/native alarm capability before scheduling.
   - If exact/native capability is denied, return a typed permission/capability failure; Dart should use local notification fallback if available.
   - Add boot restore support. After `BOOT_COMPLETED`, restore from local registry if possible and run full reconciliation on next app launch/resume.

7. Implement iOS native alarm behavior.
   - Use AlarmKit on iOS 26+ for native alarms.
   - Guard calls with iOS version checks and return unsupported below iOS 26.
   - Store native alarm identifiers so Dart registry can cancel/update.
   - If AlarmKit is unsupported or not permitted, Dart should use local notification fallback if notification permission exists.

8. Implement fallback scheduled local notifications.
   - Extend `NotificationService` or add a small collaborator so fallback scheduling supports exact local notification ids, cancellation by id, and payload routing.
   - Ensure fallback notifications use timezone-aware scheduling if required by `flutter_local_notifications`.
   - Add only minimum needed dependency support, such as `timezone`, if current setup cannot schedule future local notifications correctly.
   - Fallback tap opens `/scheduleStart` with `promptVariant: alarm`.

9. Implement reconciliation use case.
   - Add `ReconcileAlarmsUseCase`.
   - Flow:
     - Fetch alarm settings.
     - If settings unavailable, do not arm new alarms, do not immediately cancel existing registered alarms, report `settingsUnavailable`, and retry later.
     - If `alarmsEnabled=false`, cancel all local alarms/fallback notifications, clear registry, report `disabled`.
     - Register or verify current device if needed.
     - Fetch `/schedules/alarm-window` using padded schedule bounds.
     - Compute desired alarm records.
     - Skip `alarmTime <= now`.
     - Compare desired records to registry by `scheduleId` and fingerprint.
     - Cancel stale or changed records first.
     - Schedule native alarm when supported/permitted.
     - Use fallback local notification when native is unavailable/denied and notification permission exists.
     - Save final registry.
     - Post alarm status with `armedScheduleIds`, counts, coverage windows, provider info, and failures.

10. Add trigger points.
   - On successful auth/login: register current device, fetch settings, reconcile.
   - On app launch/resume: reconcile.
   - After schedule create/update/delete/finish succeeds: reconcile.
   - On global alarm toggle on: request/check permission, reconcile.
   - On global alarm toggle off: cancel all local alarms/fallback notifications, clear registry, patch backend setting.
   - On logout: unregister current device if possible, cancel all, clear registry.
   - On `DEVICE_SESSION_NOT_ACTIVE`: cancel all, clear registry, clear auth/session as appropriate, route to sign-in.
   - On early preparation start: cancel that schedule's pending alarm record.

11. Add route and launch validation.
   - Alarm payload opens `/scheduleStart` with `scheduleId` and `promptVariant: alarm`.
   - Before showing start UI, load/check latest schedule state.
   - If schedule no longer exists, is ended, or fingerprint/time no longer matches, cancel stale record and route home.
   - Do not start preparation until user confirms.

12. Add My Page alarm status UI.
   - Add a compact alarm status area in My Page/settings.
   - Show global enabled state and active delivery method:
     - Native alarm
     - Notification fallback
     - Permission needed
     - Unsupported
     - Some alarms could not be set
     - Disabled
   - Keep v1 offset fixed at 5 minutes; do not expose an offset picker yet.
   - Provide permission/setup actions only when needed.

13. Add tests.
   - Prioritize `ReconcileAlarmsUseCase` unit tests.
   - Cover:
     - Schedules only not-ended schedules in 7-day alarm coverage.
     - Requests padded schedule window.
     - Skips `alarmTime <= now`.
     - Cancels stale registry records.
     - Cancel-then-reschedule on fingerprint change.
     - Skips and reports partial when preparation data is invalid or scheduling fails.
     - Cancels all on global toggle off/logout/session invalidation.
     - Cancels schedule alarm on early preparation start.
     - Uses fallback when native is unsupported or denied.
     - Reports `settingsUnavailable` without canceling existing alarms.
   - Add repository/data-source tests for JSON contract mapping.
   - Add focused bloc/widget tests for My Page status UI and alarm-start routing where practical.

14. Add platform QA checklist.
   - Android native alarm fires when app is foreground, background, and terminated.
   - Android exact/native permission denied uses notification fallback.
   - Android reboot restore re-arms or reconciles.
   - iOS 26+ AlarmKit alarm fires and routes correctly.
   - iOS below 26 uses notification fallback or reports unsupported/permission needed.
   - Notification fallback routes to `/scheduleStart`.
   - Logout cancels local alarms.
   - New-device login invalidates old device and old app cancels on session-invalidated response.

15. Roll out safely.
   - Ship backend APIs first.
   - Ship client with reconciliation logging/status reports.
   - Keep legacy push fallback active unless latest current-device status is fresh and schedule is listed in `armedScheduleIds`.
   - Monitor `permissionNeeded`, `partial`, `settingsUnavailable`, and `platformError` rates.
   - Later add server-backed per-schedule alarm settings with `alarmEnabled`, `alarmOffsetMinutes`, and `deliveryPreference`.

## Validation

- Run `flutter analyze`.
- Run targeted reconciliation tests first, then `flutter test`.
- Run `dart run build_runner build --delete-conflicting-outputs` after adding generated models or Injectable registrations.
- Manually test Android native alarm, Android fallback, Android reboot restore, iOS 26 AlarmKit, and iOS fallback.
- Verify alarm status reports match the backend spec and legacy push suppression receives `armedScheduleIds`.

## Open Questions

- Confirm the exact iOS deployment target and build environment for AlarmKit availability.
- Confirm whether SharedPreferences or Drift should own the local alarm registry.
- Confirm final MethodChannel method names during implementation.
- Confirm backend error response envelope matches existing API conventions before coding data-source parsing.
