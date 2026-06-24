# Android Alarm And Notification QA

Use this runbook for release issue #457 after the app can be installed from a
signed release AAB or release-equivalent Android build.

## Blockers

Do not mark #457 complete until these are satisfied:

- #452 provides a signed release AAB or release-equivalent install path.
- The Play-bound Android build removes `USE_FULL_SCREEN_INTENT` and replaces
  version code 52 in every affected Play track.
- QA has access to an Android device or emulator with Google Play services, a
  backend environment with alarm APIs enabled, and a test account that can create
  schedules.

## Source Context

- Android permissions: `docs/Android-Manifest-Permissions.md`
- General native alarm checklist: `plans/native_alarm_platform_qa_checklist.md`
- Native Android bridge: `android/app/src/main/kotlin/club/devkor/ontime/`
- Dart reconciliation: `lib/domain/use-cases/reconcile_alarms_use_case.dart`
- Alarm provider/status values: `lib/domain/entities/alarm_entities.dart`

## Device Matrix

Record every device used.

| Device | Android version | Install source | Backend env | Tester | Result |
| --- | --- | --- | --- | --- | --- |
| TBD | TBD | signed release AAB or release-equivalent install | TBD | TBD | TBD |

Minimum recommended coverage:

- Android 13 or newer for `POST_NOTIFICATIONS`.
- Android 12 or newer for exact alarm special access.
- One physical device for boot restore and alarm notification behavior.

## Permission Setup

Package name:

```sh
PACKAGE=club.devkor.ontime
```

Notification permission on Android 13+:

```sh
adb shell pm grant "$PACKAGE" android.permission.POST_NOTIFICATIONS
adb shell pm revoke "$PACKAGE" android.permission.POST_NOTIFICATIONS
```

Exact alarm special access on Android 12+:

```sh
adb shell appops set "$PACKAGE" SCHEDULE_EXACT_ALARM allow
adb shell appops set "$PACKAGE" SCHEDULE_EXACT_ALARM deny
adb shell appops get "$PACKAGE" SCHEDULE_EXACT_ALARM
```

If the shell command is unavailable or ignored on the device, use Android
Settings > Apps > Special app access > Alarms and reminders, then relaunch
OnTime and re-run the scenario.

Avoid `pm clear` unless the tester intentionally wants to wipe local app data
for the test account.

## Test Data

For each scenario, create or reuse a schedule whose alarm time is soon enough to
observe without waiting through a long real-world route. Record:

| Field | Value |
| --- | --- |
| Schedule ID | TBD |
| Schedule title | TBD |
| Schedule time | TBD |
| Expected preparation start/alarm time | TBD |
| Account | TBD |
| Backend environment | TBD |
| App version/build | TBD |

## Scenarios

### 1. Notification Permission Granted

1. Grant `POST_NOTIFICATIONS`.
2. Launch OnTime and sign in.
3. Confirm notification permission copy is not blocking the app.
4. Create a near-future schedule and allow alarm reconciliation to run.
5. Record whether fallback or native alarm notifications can be shown.

Expected result: notification permission is treated as granted, and fallback
notifications are available when native alarm scheduling cannot be used.

### 2. Notification Permission Denied

1. Revoke `POST_NOTIFICATIONS`.
2. Launch OnTime and sign in.
3. Exercise the allow-notification or My Page recovery path.
4. Create a near-future schedule and allow alarm reconciliation to run.

Expected result: the app explains why schedule preparation reminders need
notifications and does not post fallback notifications while permission is
denied.

### 3. Exact Alarm Permission Granted

1. Allow `SCHEDULE_EXACT_ALARM`.
2. Grant `POST_NOTIFICATIONS`.
3. Create a near-future schedule.
4. Background the app before the expected alarm time.
5. Wait for the alarm.

Expected result: the native Android alarm provider is used, the alarm fires at
the expected time, and the alarm path opens schedule preparation.

### 4. Exact Alarm Permission Denied With Notification Granted

1. Deny `SCHEDULE_EXACT_ALARM`.
2. Grant `POST_NOTIFICATIONS`.
3. Relaunch OnTime or toggle schedule alarms off and on in My Page.
4. Create a near-future schedule and wait for the alarm time.

Expected result: the app explains precise alarm timing when recovery is needed,
uses `localNotification` fallback where available, and records/reporting should
show fallback behavior instead of native exact alarm scheduling.

### 5. Exact Alarm And Notification Denied

1. Deny `SCHEDULE_EXACT_ALARM`.
2. Revoke `POST_NOTIFICATIONS`.
3. Relaunch OnTime or toggle schedule alarms off and on in My Page.
4. Create a near-future schedule.

Expected result: no native alarm or fallback notification is armed; the app
surfaces permission recovery instead of silently claiming alarm coverage.

### 6. Alarm Notification Tap-Through

1. Allow exact alarm special access and notification permission.
2. Create a near-future schedule.
3. Lock the device or put the app in the background.
4. Wait for the alarm.
5. Tap the alarm notification to start preparing.
6. Repeat once and dismiss/cancel the ringing alarm instead of starting.

Expected result: an alarm notification appears for the user-scheduled alarm
moment, tapping it opens `AlarmRingingActivity`, the start action routes into
schedule preparation, and dismissal stops ringing/vibration and removes the
alarm notification.

### 7. Cancellation

1. Create a near-future schedule with permissions granted.
2. Before the alarm time, start preparation early, finish the schedule, delete
   the schedule, or disable schedule alarms in My Page.
3. Wait past the original alarm time.

Expected result: no alarm or fallback notification fires after cancellation.

### 8. Boot Restore

1. Allow exact alarm special access and notification permission.
2. Create a future schedule far enough out to reboot the device.
3. Restart the device.
4. Unlock and wait for the expected alarm time. If practical, also open OnTime
   once after boot to trigger app reconciliation.

Expected result: future native alarms are restored where Android permits boot
restore, and any failure is recorded with the device model and Android version.

## Evidence Form

Attach this evidence to #457 or the release QA record.

| Item | Evidence |
| --- | --- |
| Device model | TBD |
| Android version/API | TBD |
| App version/build number | TBD |
| Install source or artifact path | TBD |
| Backend environment | TBD |
| Test account | TBD |
| Notification granted result | TBD |
| Notification denied result | TBD |
| Exact alarm granted result | TBD |
| Exact alarm denied + notification granted result | TBD |
| Exact alarm denied + notification denied result | TBD |
| Full-screen alarm UI result | TBD |
| Fallback notification result | TBD |
| Cancellation result | TBD |
| Boot restore result | TBD |
| Failures and logs | TBD |
| Screenshots/recordings | TBD |

## Failure Triage

For any failure, record:

- Scenario name and permission state.
- Schedule ID, expected alarm time, actual observed time, and timezone.
- Whether the app was foregrounded, backgrounded, terminated, locked, or after
  reboot.
- Screenshot or screen recording.
- Relevant `adb logcat` excerpt filtered to `OnTime`, `Alarm`, or
  `club.devkor.ontime`, without personal account data.
- Whether the issue reproduces after reinstalling the same artifact.
