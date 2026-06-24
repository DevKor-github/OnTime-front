# Android Manifest Permission Audit

This audit records the Android manifest permission review for release issue
#442 under parent track #465.

## Source Manifests Reviewed

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/profile/AndroidManifest.xml`

The main manifest is the app-owned release source of truth. Debug and profile
manifests only add `android.permission.INTERNET` for Flutter tooling and hot
reload.

## Release Permission Inventory

| Permission | Status | Justification |
| --- | --- | --- |
| `android.permission.POST_NOTIFICATIONS` | Keep | Required on Android 13+ for OnTime reminder, preparation-step, and alarm notifications. Native alarm handling also checks this permission before posting alarm notifications. |
| `android.permission.SCHEDULE_EXACT_ALARM` | Keep | Required on Android 12+ for user-scheduled schedule alarms that must fire at the selected time. Native alarm scheduling checks `AlarmManager.canScheduleExactAlarms()` before using `setAlarmClock`. |
| `android.permission.RECEIVE_BOOT_COMPLETED` | Keep | Required for `NativeAlarmBootReceiver` to restore persisted future native alarms after device restart. The receiver is not exported. |
| `android.permission.VIBRATE` | Keep | Required so alarm and notification channels can use vibration behavior for time-sensitive reminders and alarms. |

No unused app-owned release permission remains in the manifest.

## Removed Permission

| Permission | Status | Reason |
| --- | --- | --- |
| `android.permission.USE_FULL_SCREEN_INTENT` | Removed | Google Play rejected OnTime's declaration for version code 52 and instructed the team to remove this permission from all submitted version codes. OnTime must not declare this permission or call `setFullScreenIntent(...)` in Play-bound builds. |

## Manifest Merge Notes

Release manifest merge was verified with:

```sh
ANDROID_KEYSTORE_PATH=$HOME/.android/debug.keystore \
ANDROID_KEYSTORE_PASSWORD=android \
ANDROID_KEY_ALIAS=androiddebugkey \
ANDROID_KEY_PASSWORD=android \
gradle :app:processReleaseMainManifest -x :app:compileFlutterBuildRelease
```

The command used ignored local placeholder release config only to allow manifest
merge without production Firebase and signing secrets.

The merged release manifest contains the app-owned permissions above plus these
dependency-owned permissions:

| Permission | Source | Justification |
| --- | --- | --- |
| `android.permission.INTERNET` | Google Sign-In, Firebase Messaging, AppAuth, and related network dependencies | Required for sign-in, Firebase initialization/messaging, and app network access. |
| `android.permission.WAKE_LOCK` | `firebase_messaging` / Firebase Messaging | Required by Firebase Messaging background delivery while processing incoming messages. |
| `android.permission.ACCESS_NETWORK_STATE` | Firebase Messaging / Firebase Installations / Google transport dependencies | Required by Firebase and transport dependencies to check network availability for messaging and token/installation work. |
| `com.google.android.c2dm.permission.RECEIVE` | Firebase Messaging | Required for receiving FCM push messages. |
| `android.permission.USE_BIOMETRIC` | AndroidX biometric via Google credential dependencies | Added by AndroidX credential/biometric dependencies used by Google sign-in support. |
| `android.permission.USE_FINGERPRINT` | AndroidX biometric via Google credential dependencies | Legacy counterpart to `USE_BIOMETRIC` from the same dependency chain. |
| `club.devkor.ontime.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX core | Signature-level internal permission used by AndroidX for non-exported dynamic receiver protection. |

The merge did not add location, contacts, camera, microphone, phone, SMS,
storage, calendar, nearby-device, or Bluetooth permissions.

Debug and profile merged manifests may additionally contain their variant-owned
`android.permission.INTERNET` declaration for Flutter tooling.

## Related Android Components

- `MainActivity` checks exact alarm and notification permission state before
  scheduling native alarms.
- `NativeAlarmReceiver` posts alarm-category notifications and skips posting
  when notification permission is denied.
- `NativeAlarmBootReceiver` handles boot completion and exact-alarm permission
  state changes to restore persisted native alarms.
- `AlarmRingingActivity` is the tap-through alarm UI launched from the alarm
  notification content intent.
