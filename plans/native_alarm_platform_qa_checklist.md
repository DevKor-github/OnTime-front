# Native Alarm Platform QA Checklist

Run this after backend alarm APIs are available and the app has valid Firebase
configuration for Android/iOS builds.

## Android

- Native alarm fires while the app is foregrounded.
- Native alarm fires while the app is backgrounded.
- Native alarm opens `/scheduleStart` after app termination.
- Android 12+ exact alarm denied: enabling schedule alarms shows precise-timing rationale and Android alarm/reminder settings recovery.
- Android 12+ exact alarm denied with notification permission allowed: reconciliation arms `localNotification` fallback and reports fallback provider.
- Android 12+ exact alarm denied with notification permission denied: reconciliation reports `permissionNeeded` with `nativePermissionDenied`.
- Android 12+ exact alarm allowed after settings recovery: relaunching or toggling schedule alarms reconciles future records as `androidAlarmManager`.
- Alarm payload validation redirects home for deleted, ended, or fingerprint-changed schedules.
- Notification fallback is used when native alarm scheduling is unavailable.
- Notification fallback opens `/scheduleStart` with `promptVariant=alarm`.
- Reboot after scheduling a native alarm restores future `androidAlarmManager` registry entries.
- Logout cancels native alarms, cancels fallback notifications, clears registry, and unregisters the device.
- Old-device `DEVICE_SESSION_NOT_ACTIVE` status response cancels local alarms, clears registry, and signs out.

## iOS

- iOS 26+ returns `iosAlarmKit` capabilities when built with an SDK that includes AlarmKit.
- iOS 26+ requests AlarmKit authorization and maps authorized/denied/notDetermined to Dart permission states.
- iOS 26+ AlarmKit alarm fires at the scheduled alarm time.
- AlarmKit Open action stores the alarm payload and `/scheduleStart` validates before showing the prompt.
- AlarmKit cancellation removes the scheduled alarm for changed, deleted, finished, or disabled schedules.
- iOS below 26 returns unsupported native capability and uses notification fallback when notification permission is granted.
- Notification fallback opens `/scheduleStart` with `promptVariant=alarm`.
- Logout cancels fallback notifications, clears registry, and unregisters the device.

## Backend Status

- Fresh status reports include padded schedule window, 7-day alarm coverage, provider fields, counts, and `armedScheduleIds`.
- Backend legacy push suppression keeps fixed push reminders only when current-device status is stale or missing the schedule id.
- Monitor `permissionNeeded`, `partial`, `settingsUnavailable`, `platformError`, and `DEVICE_SESSION_NOT_ACTIVE` rates during rollout.
