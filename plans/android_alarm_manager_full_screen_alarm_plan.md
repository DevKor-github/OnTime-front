# Android AlarmManager Full-Screen Alarm Plan

## Goal

Make Android alarm delivery work like iOS in reliability and app ownership, even if Android does not use OS Clock UI.

The target Android behavior is:

- App-owned exact alarms for future schedule alarm times.
- Stable OnTime alarm IDs for cancel/update.
- No requirement that the user reopen OnTime within 24 hours.
- Alarm restoration after reboot.
- A dedicated full-screen alarm screen that wakes the display and appears over the lock screen.
- System default alarm ringtone and repeating vibration.
- Local dismissal only.
- `Start preparing` hands off to the existing Flutter schedule-start flow.
- Local notification fallback only when exact alarm permission is denied.

This plan supersedes the earlier `androidSystemClock` direction in `plans/native_alarm_ios_android_parity_plan.md`.

## Context

Current iOS implementation:

- `ios/Runner/AppDelegate.swift` exposes `on_time_front/native_alarm`.
- iOS 26+ uses AlarmKit with `AlarmManager.shared.schedule(id:configuration:)`.
- iOS has app-owned alarm IDs, exact future alarm scheduling, cancel/update, system presentation, and a secondary intent that opens OnTime through `ontime://alarm`.

Current Android implementation in this worktree:

- `android/app/src/main/kotlin/club/devkor/ontime/MainActivity.kt` exposes the same MethodChannel.
- Android has an existing `AlarmManager.setAlarmClock(...)` path.
- Android has experimental receiver-to-activity launch code and `AlarmLaunchActivity` from earlier debugging.
- Android was temporarily moved toward `androidSystemClock` / `AlarmClock.ACTION_SET_ALARM`, but that path is no longer desired because it loses app-owned IDs, exact future dates, and reliable cancel/update.
- `NativeAlarmBootReceiver` already restores local registry records for `androidAlarmManager`.
- Flutter reconciliation, registry, and status reporting already understand scheduled alarm records, stable IDs, providers, and fallback notifications.

Official Android constraints:

- `AlarmManager.setAlarmClock(...)` and exact alarms can schedule app-owned alarms at exact timestamps.
- App-owned `AlarmManager` alarms can be canceled by recreating the matching `PendingIntent`.
- `AlarmManager` alarms are cleared by reboot, so app restore from local registry is required.
- Android background activity starts are restricted; launching an activity directly from a broadcast is not reliable.
- Android's supported pattern for urgent alarm/call presentation is a high-importance notification with a full-screen intent. For alarm apps, this can wake the screen and show an alarm activity.

## Decisions

- Use `AlarmProvider.androidAlarmManager` as Android's primary native provider.
- Remove `AlarmProvider.androidSystemClock` from production code, tests, and status serialization.
- Android should report:
  - `supportsNativeAlarm=true`
  - `nativeAlarmProvider=androidAlarmManager`
  - `fallbackProvider=localNotification`
- Keep iOS AlarmKit unchanged.
- Replace the experimental `AlarmLaunchActivity` with a purpose-built native `AlarmRingingActivity`.
- The native ringing activity should own sound, vibration, dismiss, and start actions before handing off to Flutter.
- Use the system default alarm ringtone by default.
- Auto-stop sound/vibration after 60 seconds, then leave the screen in a visible stopped/missed state if still open.
- Wake the screen and show over lock screen.
- Notification shade should expose a minimal `Dismiss` action.
- Full-screen alarm activity should expose `Start preparing` and `Dismiss`.
- `Start preparing` should not mutate schedule state natively; it should open Flutter with the existing alarm payload and let the existing app flow decide.
- `Dismiss` should stay local in v1: stop sound/vibration, cancel the notification, and finish or settle the native screen without backend writes.
- Use local-notification fallback only when exact alarm permission is denied or unavailable.
- Restore future `androidAlarmManager` alarms after reboot using the local registry.

## Steps

1. Remove the Clock-app provider path.
   - Delete `AlarmProvider.androidSystemClock`.
   - Remove `androidSystemClock` wire parsing/serialization and upper-snake status values.
   - Remove Clock-specific failure reasons if no longer used, such as `cancelUnsupported`, `clockAppUnavailable`, and `clockAppConfirmationRequired`.
   - Remove `AlarmClock.ACTION_SET_ALARM`, `SET_ALARM` permission, and package query additions from Android.
   - Remove Android system-Clock 24-hour coverage behavior from reconciliation.

2. Restore Android capability reporting.
   - In `MainActivity.kt`, report `nativeAlarmProvider=androidAlarmManager`.
   - Report `fallbackProvider=localNotification`.
   - `checkPermission` and `requestPermission` should use exact alarm permission state for Android 12+.
   - If exact alarm permission is denied, Flutter reconciliation should use local notification fallback.

3. Rework `AlarmManager` scheduling.
   - Use `AlarmManager.setAlarmClock(...)` with the schedule's exact `triggerAtMillis`.
   - Use a stable request code from `nativeAlarmId`.
   - The operation `PendingIntent` should target `NativeAlarmReceiver`.
   - The `showIntent` should target the new `AlarmRingingActivity`.
   - The receiver should also post the full-screen notification so the activity can surface reliably from background/locked states.
   - Keep logs for schedule ID, native ID, trigger time, current time, permission state, and selected presentation path.

4. Replace the experimental activity.
   - Delete or stop registering `AlarmLaunchActivity`.
   - Add `AlarmRingingActivity`.
   - Configure it with:
     - `showWhenLocked`
     - `turnScreenOn`
     - full-screen layout/theme
     - excluded-from-recents behavior if appropriate
   - Render a simple native alarm screen with:
     - schedule title
     - alarm/preparation time context
     - `Start preparing`
     - `Dismiss`
     - stopped/missed state after auto-stop

5. Implement native ringing behavior.
   - On activity start, play the system default alarm ringtone.
   - Start repeating vibration.
   - Stop sound/vibration after 60 seconds automatically.
   - Stop immediately on `Dismiss` or `Start preparing`.
   - Handle lifecycle defensively so sound/vibration are stopped on finish/destroy.

6. Implement notification/full-screen presentation.
   - Create a high-importance alarm notification channel.
   - Post a notification with category alarm.
   - Attach a full-screen intent to `AlarmRingingActivity`.
   - Add a `Dismiss` notification action that stops ringing and cancels the notification.
   - Keep notification content minimal because the main UX is the full-screen activity.
   - Do not post the old normal schedule notification card for `schedule_alarm`.

7. Implement dismiss action handling.
   - Add a native dismiss broadcast/action if needed.
   - Ensure dismiss cancels the active alarm notification.
   - Ensure dismiss stops sound/vibration if the ringing activity/process is alive.
   - Do not call backend APIs from native Android in v1.

8. Implement Flutter handoff for `Start preparing`.
   - Reuse the existing alarm payload structure where possible.
   - `Start preparing` opens `MainActivity` with `ACTION_SCHEDULE_ALARM` and the payload.
   - Flutter receives the payload through `getLaunchPayload` or `alarmLaunch`.
   - Existing Flutter routing should handle navigation to the preparation/start flow.

9. Keep cancel/update reliable.
   - `cancelNativeAlarm` should recreate the exact matching `PendingIntent` and call `AlarmManager.cancel(...)`.
   - It should also cancel any active alarm notification for that native ID.
   - Schedule updates should cancel stale registry records before scheduling the new record.
   - Logout, disable alarms, finish/delete schedule, and session invalidation should continue to cancel registered alarms.

10. Keep reboot restore.
    - `NativeAlarmBootReceiver` should restore future `androidAlarmManager` records from the registry.
    - It should skip expired records.
    - It should not try to restore removed `androidSystemClock` records except as a migration cleanup.
    - It should log restore count, skipped count, and failures.

11. Update fallback and status behavior.
    - If exact alarm permission is granted, status should report `nativeAlarmProvider=androidAlarmManager` and `fallbackProvider=none` when native alarms are armed.
    - If exact alarm permission is denied and notification permission is granted, schedule local notifications and report `fallbackProvider=localNotification`.
    - If both are denied, report permission-needed.
    - Settings copy should say exact alarm permission is required for full alarm behavior.

12. Update tests.
    - Remove `androidSystemClock` tests.
    - Add reconciliation tests for:
      - exact native Android alarm coverage remains seven days
      - exact permission denied falls back to local notification
      - stale native alarm cancel/update
      - no 24-hour Clock-app limit
      - status provider values
    - Add model tests for provider serialization.
    - Add Android compile validation for Kotlin changes.

## Validation

- `dart format lib test`
- `flutter analyze`
- `flutter test test/domain/use-cases/reconcile_alarms_use_case_test.dart`
- `flutter test test/data/models/alarm_models_test.dart`
- `flutter test test/core/services/alarm_scheduler_service_test.dart`
- `flutter test test/data/data_sources/alarm_remote_data_source_test.dart`
- `./gradlew :app:compileDebugKotlin`
- Manual Android:
  - Full reinstall.
  - Grant exact alarm permission and notification permission.
  - Create a schedule more than 24 hours away and verify it is registered locally as `androidAlarmManager`.
  - Update the schedule and verify the old alarm is canceled and new alarm is registered.
  - Reboot and verify future alarms restore.
  - Lock screen, wait for alarm, verify screen wakes and native full-screen alarm appears.
  - Verify system default alarm ringtone and vibration start.
  - Verify sound/vibration auto-stop after 60 seconds.
  - Verify `Dismiss` stops local alarm state and notification without backend writes.
  - Verify `Start preparing` opens OnTime and routes through the existing Flutter flow.
  - Deny exact alarm permission and verify local notification fallback.
- Manual iOS:
  - Confirm AlarmKit scheduling and secondary intent still work.

## Done Criteria

- Android no longer reports or schedules `androidSystemClock`.
- Android primary path uses app-owned exact `AlarmManager` alarms.
- Android alarms can be canceled/updated by schedule ID/native ID.
- Android alarms can be scheduled beyond 24 hours without requiring app reopen.
- A native full-screen alarm activity appears over lock screen from the full-screen alarm notification path.
- Sound/vibration behavior matches the decisions above.
- Fallback behavior works when exact alarm permission is denied.
- Existing iOS AlarmKit behavior remains unchanged.

## Open Questions

- None for v1. The major product decisions have been resolved through the grill-me flow.
