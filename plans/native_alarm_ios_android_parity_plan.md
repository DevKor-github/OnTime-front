# Native Alarm iOS Android Parity Plan

> Superseded: the Android Clock-app direction in this plan was replaced by
> `plans/android_alarm_manager_full_screen_alarm_plan.md`, which targets
> iOS-like reliability through app-owned `AlarmManager` alarms and a native
> full-screen Android ringing activity.

## Goal

Make Android alarm delivery as close as possible to the current iOS AlarmKit behavior while being honest about platform limits.

The target product behavior is:

- iOS 26+: use AlarmKit for system-managed alarm presentation.
- Android: avoid schedule-alarm notifications for the primary alarm path.
- Android: prefer real OS alarm-clock behavior over app-owned notification fallback.
- Both platforms: keep server schedules as source of truth and keep Flutter reconciliation as the local mirror.

## Context

Current iOS implementation:

- `ios/Runner/AppDelegate.swift` exposes `on_time_front/native_alarm`.
- iOS 26+ reports `supportsNativeAlarm=true`, `nativeAlarmProvider=iosAlarmKit`, and `fallbackProvider=localNotification`.
- iOS schedules with `AlarmManager.shared.schedule(id:configuration:)`.
- iOS uses `AlarmManager.AlarmConfiguration.alarm(...)`, `AlarmPresentation.Alert`, `AlarmButton`, and `secondaryIntent`.
- `OpenScheduleAlarmIntent` stores payload and opens the app through `ontime://alarm`.
- Below iOS 26 or without AlarmKit, iOS falls back to local notifications.

Current Android implementation in this worktree:

- `android/app/src/main/kotlin/club/devkor/ontime/MainActivity.kt` exposes the same MethodChannel.
- Android reports `nativeAlarmProvider=androidAlarmManager` and currently `fallbackProvider=none`.
- Android schedules with `AlarmManager.setAlarmClock(...)`.
- The operation `PendingIntent` fires `NativeAlarmReceiver`; the receiver attempts to surface `AlarmLaunchActivity`.
- Multiple direct activity launch approaches were tried:
  - `setAlarmClock(..., activityPendingIntent)` did not fire reliably on the tested device.
  - Broadcast receiver plus `startActivity(...)` fired but did not surface `MainActivity`.
  - Broadcast receiver plus `PendingIntent.send(...)` with Android 14+ background-start options also returned success but did not surface Flutter UI.
  - A dedicated `AlarmLaunchActivity` task was added, but should be treated as experimental until verified.
- Android schedule-alarm FCM/local-notification display is suppressed in `NotificationService` for `schedule_alarm` payloads, but server notification payloads may still be displayed by Android before Flutter handles them.

Official API facts verified:

- Android `AlarmManager.setAlarmClock` schedules an alarm that represents an alarm clock and is used to notify the user when it goes off. Android also expects the app to further wake/tell the user by turning on the screen, playing sound, vibrating, etc. Source: https://developer.android.com/reference/android/app/AlarmManager
- Android 10+ restricts background activity starts, and Android 14/15/16 add explicit `PendingIntent` background activity start opt-ins. These opt-ins are conditions, not a guarantee that arbitrary app UI will surface on every device/OEM state. Source: https://developer.android.com/guide/components/activities/background-starts
- Android `AlarmClock.ACTION_SET_ALARM` delegates to an alarm clock application and activates or creates a real alarm. It supports hour, minute, label/message, ringtone, vibration, and `EXTRA_SKIP_UI`. Source: https://developer.android.com/reference/android/provider/AlarmClock
- Android full-screen intent is the platform-supported way for alarm/calling apps to show urgent app UI from notifications, and Android 14+ limits this permission to apps whose core function is alarm/calling. Source: https://source.android.com/docs/core/permissions/fsi-limits
- Apple AlarmKit provides an alarm configuration that behaves like a traditional alarm with system presentation, buttons, sound, metadata, and intents. Sources:
  - https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration/alarm(schedule:attributes:stopintent:secondaryintent:sound:)
  - https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit
  - https://developer.apple.com/documentation/alarmkit/alarmmanager/schedule(id:configuration:)

## API Difference Summary

| Capability | iOS AlarmKit | Android `setAlarmClock` | Android `AlarmClock.ACTION_SET_ALARM` |
| --- | --- | --- | --- |
| Third-party app can schedule system alarm | Yes, iOS 26+ | Yes, alarm-clock-class trigger | Yes, delegated to Clock/alarm app |
| System owns alarm presentation | Yes | Partly; app must present alert/sound/UI | Yes, Clock app owns presentation |
| Branded app alarm UI | Yes via AlarmKit presentation metadata/tint/buttons | Only reliably via full-screen notification or foreground app | No, Clock UI is system/Clock app UI |
| App callback at fire time | Via intents/actions | Broadcast/service/activity pending intent, subject to background-start limits | No reliable app callback at ring time |
| Open app from alarm UI | Secondary intent can open app | Full-screen notification or background launch attempts; not reliable without notification | Generally not app-controlled |
| Stable cancel by app ID | Yes, app-defined Alarm ID | Yes, matching PendingIntent/request code | Weak; Clock intents do not give a stable app-owned alarm ID |
| Reboot restore | AlarmKit/system handles alarm state | App must restore or rely on AlarmManager persistence behavior; current app restores registry | Clock app owns created alarm |
| Looks like built-in alarm | Yes | Only if app builds comparable UI or uses FSI | Yes |

## Decisions

- Android cannot have exact iOS AlarmKit parity with an OnTime-owned system alarm UI because Android does not provide a third-party AlarmKit equivalent.
- If "not notification" is non-negotiable, Android should delegate primary alarm creation to the system Clock app using `AlarmClock.ACTION_SET_ALARM`.
- Android `AlarmManager.setAlarmClock` should remain available as a diagnostic/native scheduling mode, but not be described as equivalent to iOS AlarmKit presentation.
- Android full-screen-intent notification is the best OnTime-branded alarm UI path, but it violates the user's current "not notification" requirement. Keep it out of the primary plan unless the product later accepts notification-backed full-screen alarm UI.
- Backend must stop sending notification-display payloads for schedule alarms when the current device reports native/system alarm coverage. Client-side suppression is not enough for notification payloads.
- Reconciliation should record Android system-clock alarms separately from `androidAlarmManager` alarms because capabilities and cancellation guarantees differ.

## Recommended Android Target

Use a new Android provider:

```text
androidSystemClock
```

This provider means:

- The app creates a real alarm in the user's Clock/alarm app via `AlarmClock.ACTION_SET_ALARM`.
- The alarm rings with the device/system alarm UI and ringtone.
- The app does not post a schedule-alarm notification.
- OnTime can still keep a local registry and server diagnostic status, but cancellation and mutation are best-effort because Android's public Clock intent API does not return a stable alarm identifier.
- OnTime should only mirror near-term Android Clock alarms. The public Clock intent accepts hour/minute rather than a calendar date, so a schedule several days away could otherwise become the next alarm with the same time-of-day.

This is the closest match to "make the alarm the alarm app alarm like iOS" without using notifications.

## Steps

1. Add provider modeling.
   - Add `AlarmProvider.androidSystemClock`.
   - Update wire-value parsing/serialization.
   - Update backend status tests/models to allow `androidSystemClock`.
   - Keep `androidAlarmManager` for the existing `setAlarmClock` implementation if we want diagnostics or future fallback.

2. Split Android scheduling modes.
   - In `MainActivity.kt`, add a MethodChannel mode or choose provider capability:
     - `androidSystemClock` for user-facing primary path.
     - `androidAlarmManager` only for app-owned experimental path.
   - For primary Android capability, return:
     - `supportsNativeAlarm=true`
     - `nativeAlarmProvider=androidSystemClock`
     - `fallbackProvider=none`

3. Implement Android system Clock scheduling.
   - Convert `record.alarmTime` into local hour/minute.
   - Start an intent:
     - `AlarmClock.ACTION_SET_ALARM`
     - `AlarmClock.EXTRA_HOUR`
     - `AlarmClock.EXTRA_MINUTES`
     - `AlarmClock.EXTRA_MESSAGE` with a concise label such as `OnTime: <scheduleTitle>`
     - `AlarmClock.EXTRA_VIBRATE=true`
     - `AlarmClock.EXTRA_SKIP_UI=true` only after testing on target devices; otherwise use `false` to let users confirm and understand Clock ownership.
   - Add `<uses-permission android:name="com.android.alarm.permission.SET_ALARM" />`.
   - Handle `ActivityNotFoundException` as `unsupported`.
   - Log the selected Clock package/activity when resolvable.

4. Model cancellation honestly.
   - Android public `AlarmClock.ACTION_SET_ALARM` does not give the app a stable alarm ID.
   - Use one of these policies:
     - Recommended v1: one-shot Clock alarms are not auto-canceled by OnTime; schedule mutation creates a new Clock alarm and marks the old local registry record as `cancelUnsupported`.
     - Better but more complex: attempt `AlarmClock.ACTION_DISMISS_ALARM` by label/search mode where available, but treat it as best-effort and test per device.
   - Update `CancelScheduleAlarmUseCase` and `CancelAllAlarmsUseCase` to treat `androidSystemClock` cancellation as best-effort/no-op with a visible diagnostic status.

5. Adjust reconciliation for system Clock semantics.
   - If provider is `androidSystemClock`, schedule only future alarms that are far enough ahead to avoid creating stale Clock alarms.
   - Disable the recently-missed 30-second catch-up for `androidSystemClock`; system Clock alarms are minute-granularity and should not create confusing immediate alarms.
   - If schedule changes, mark previous registry record stale and create a new Clock alarm.
   - Report failures distinctly:
     - `cancelUnsupported`
     - `clockAppUnavailable`
     - `clockAppConfirmationRequired`
   - Consider status `partial` if stale Clock alarms may remain after schedule changes.

6. Stop duplicate notifications end to end.
   - Keep client-side `schedule_alarm` FCM/local notification suppression.
   - Change backend to send data-only messages or no schedule-alarm FCM notification payload when the active device has `nativeAlarmProvider=androidSystemClock` and current coverage includes the schedule.
   - Do not rely on Flutter to suppress notification payloads; Android can display notification payloads before Dart runs.

7. Keep iOS AlarmKit path as the higher-fidelity implementation.
   - Leave current AlarmKit scheduling, metadata, presentation, and secondary intent structure.
   - Add tests/docs that iOS has app-owned system alarm UI while Android system Clock has system-owned alarm UI with weaker app callback/cancellation.

8. Update settings and status UI copy.
   - Android `androidSystemClock`: "Uses your device Clock app for alarms."
   - Android `androidAlarmManager` experimental: "Uses OnTime alarm trigger; may require full-screen notification permission for app UI."
   - Permission-needed state should mention exact alarm permission only for `androidAlarmManager`, not for system Clock intent if it does not require it.

9. Update QA.
   - Test Android system Clock creation with `EXTRA_SKIP_UI=false` and `true`.
   - Test Samsung/Pixel emulator or physical devices separately.
   - Test schedule create, update, delete, logout, and duplicate prevention.
   - Verify no `FLTFireMsgReceiver` schedule notification appears when server status says covered.
   - Verify iOS AlarmKit still schedules and opens app via secondary action.

10. Clean up experimental Android activity-launch code.
   - After selecting `androidSystemClock`, remove or quarantine:
     - `AlarmLaunchActivity`
     - background activity start option reflection
     - receiver-to-activity launch attempts
   - Keep `NativeAlarmBootReceiver` only if `androidAlarmManager` remains supported.

## Validation

- `flutter analyze`
- `flutter test test/domain/use-cases/reconcile_alarms_use_case_test.dart`
- `flutter test test/data/models/alarm_models_test.dart`
- `flutter test test/data/data_sources/alarm_remote_data_source_test.dart`
- Android manual:
  - Full reinstall.
  - Create a schedule alarm.
  - Confirm Clock app alarm is created.
  - Confirm alarm rings with system Clock UI.
  - Confirm no OnTime notification bubble appears.
  - Confirm backend status says `nativeAlarmProvider=androidSystemClock`.
- iOS manual:
  - iOS 26+ AlarmKit authorization.
  - AlarmKit alarm fires with system alarm UI.
  - Secondary action opens OnTime `/scheduleStart`.

## Open Questions

- Should Android use `AlarmClock.EXTRA_SKIP_UI=true` by default?
  - Recommended answer: start with `false` for the first QA pass so users and testers can see the Clock alarm being created; switch to `true` only if target devices create one-shot alarms reliably without UI.
- Should OnTime accept losing automatic cancellation for Android system Clock alarms?
  - Recommended answer: yes, if "no notification and real alarm app alarm" is the priority. Document this tradeoff in settings and status.
- Should `androidAlarmManager` remain as an advanced/experimental provider?
  - Recommended answer: keep it behind a debug flag only. The tested devices show alarm broadcasts fire, but app UI launch from background is unreliable without notification/full-screen intent.
- Should Android full-screen-intent notification be allowed as a future optional mode?
  - Recommended answer: yes, as a separate user-selectable "OnTime full-screen alarm" mode if product later accepts notification-backed alarm UI.
