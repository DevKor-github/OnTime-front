# Google Play Full-Screen Intent Declaration

This document prepares the Play Console review material for issue #445 under
parent track #465. It is not a record of submission. A human with Play Console
access must submit the declaration and attach release-candidate QA evidence.

Checked against Google policy guidance on 2026-05-10:

- Google Play policy: `USE_FULL_SCREEN_INTENT` on Android 14+ is auto-granted
  only for apps whose core function is setting alarms or handling calls, and
  apps targeting Android 14+ should submit the Play Console declaration to
  establish pre-grant eligibility.
  https://support.google.com/googleplay/android-developer/answer/16558241?hl=en
- Android platform guidance: Google Play revokes full-screen intent permission
  for installed apps that do not have calling or alarm functionality.
  https://source.android.com/docs/core/permissions/fsi-limits

## Declaration Position

OnTime should declare `USE_FULL_SCREEN_INTENT` for the setting-an-alarm use
case.

OnTime is a schedule preparation and reminder app. Users create schedule entries
and enable schedule alarms so the app can alert them at the preparation start
time. The full-screen intent is reserved for that user-scheduled alarm moment,
when the user needs immediate, time-sensitive notice to start preparing for a
schedule.

The app does not use full-screen intent for marketing, ads, generic push
messages, preparation-step notifications, or other low-priority notifications.

## Play Console Draft Text

Use case category:

```text
Setting an alarm
```

Short justification:

```text
OnTime uses full-screen intent only for user-scheduled schedule alarms. Users
create schedules and enable alarms/reminders so OnTime can alert them at the
preparation start time. The full-screen alarm UI appears only when a scheduled
alarm fires and helps the user start or dismiss that alarm.
```

Detailed reviewer explanation:

```text
OnTime's core functionality is schedule preparation with alarms/reminders. A
user can create a schedule and enable schedule alarms. When an alarm time is
reached, OnTime posts an Android alarm-category notification with a full-screen
intent to show the alarm UI. The full-screen UI contains only alarm controls,
including "Start preparing" and "Dismiss", and routes the user into the
schedule preparation flow.

Full-screen intent is not used for promotional content, ads, generic app
updates, social messages, or ordinary push notifications. Non-alarm push and
local notifications use normal notification channels. Payloads identified as
schedule_alarm are suppressed from the generic notification path so the native
alarm path owns alarm presentation.
```

Reviewer evidence to attach:

```text
1. AndroidManifest.xml declares USE_FULL_SCREEN_INTENT for the app-owned alarm
   behavior.
2. NativeAlarmReceiver posts the only full-screen notification and marks it as
   Notification.CATEGORY_ALARM.
3. AlarmRingingActivity is the full-screen UI and only exposes alarm actions:
   Start preparing and Dismiss.
4. NotificationService suppresses schedule_alarm payloads in generic push/local
   notification paths.
5. QA evidence shows a user-created schedule alarm firing on a locked/off-screen
   Android device and shows generic notifications do not launch full-screen UI.
```

## Source Evidence

Manifest permission:

- `android/app/src/main/AndroidManifest.xml` declares
  `android.permission.USE_FULL_SCREEN_INTENT`.
- The release permission audit keeps this permission only for the
  user-scheduled alarm ringing notification:
  `docs/Android-Manifest-Permissions.md`.

Full-screen notification path:

- `android/app/src/main/kotlin/club/devkor/ontime/NativeAlarmReceiver.kt`
  creates channel `on_time_alarm_full_screen`, sets
  `Notification.CATEGORY_ALARM`, sets priority `PRIORITY_MAX`, and calls
  `setFullScreenIntent(fullScreenIntent, true)`.
- The receiver skips posting the alarm notification if Android 13+
  notification permission is denied.

Full-screen alarm UI:

- `android/app/src/main/kotlin/club/devkor/ontime/AlarmRingingActivity.kt`
  is configured as the alarm UI with `showWhenLocked`, `turnScreenOn`, and
  alarm-only controls.
- `AlarmRingingActivity` captures alarm payload fields and forces
  `type=schedule_alarm` and `promptVariant=alarm`.

Scheduling and routing:

- `android/app/src/main/kotlin/club/devkor/ontime/MainActivity.kt` schedules
  native alarms through `AlarmManager.setAlarmClock` and supplies the
  full-screen activity pending intent as the alarm clock show intent.
- `lib/domain/use-cases/reconcile_alarms_use_case.dart` derives desired alarm
  records from schedule and preparation data and schedules only future alarm
  times within the alarm coverage window.
- `lib/core/services/alarm_scheduler_service.dart` passes schedule alarm
  payloads to the native alarm channel.
- `lib/core/services/notification_service.dart` suppresses `schedule_alarm`
  payloads from generic FCM/local notification display and routes alarm taps to
  `/scheduleStart`.

## QA Checklist For Submission Evidence

Record the app version, Android device model, Android version, build type, and
timestamp for each run.

- User-scheduled alarm fires while the screen is locked and opens the full-screen
  alarm UI.
- User-scheduled alarm fires while the screen is off and opens the full-screen
  alarm UI.
- The full-screen alarm UI shows alarm-only controls and no promotional or
  generic content.
- Tapping "Start preparing" opens the schedule preparation flow for the alarm
  schedule.
- Tapping "Dismiss" stops the alarm UI and clears the alarm notification.
- A generic push notification does not open a full-screen UI.
- A preparation-step notification does not open a full-screen UI.
- Android 13+ notification-denied state does not post the full-screen alarm
  notification.
- Android 12+ exact-alarm-denied state does not schedule a native full-screen
  alarm and instead follows the documented permission/fallback behavior.

## Play Console Submission Steps

1. Open the target app in Play Console.
2. Open the app content or policy declaration area that contains full-screen
   intent permission declarations for the active Android target level.
3. Select the alarm use case for `USE_FULL_SCREEN_INTENT`.
4. Paste the short justification and reviewer explanation above.
5. Attach or reference QA evidence from the release-candidate build.
6. Confirm the app listing describes schedule preparation, reminders, and alarms
   consistently with `docs/Google-Play-Listing-Copy.md`.
7. Submit the declaration.
8. Update #445 with the submission date, reviewer evidence location, device/OS
   matrix, and any Play Console response.

## Remaining Human Tasks

- Submit the Play Console declaration from an authorized account.
- Run and record the QA checklist on release-candidate Android builds.
- Attach screenshots or screen recordings that show full-screen behavior only
  for user-scheduled alarms.
- Leave #445 open until declaration submission and QA evidence are complete.

