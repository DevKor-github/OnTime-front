# Google Play Full-Screen Intent Compliance

This file used to hold the reviewer argument for declaring
`USE_FULL_SCREEN_INTENT`. Google Play rejected that declaration for OnTime
version code 52 and instructed the team to remove the permission from all
submitted version codes.

Current release position:

- Do not declare `android.permission.USE_FULL_SCREEN_INTENT`.
- Do not call `Notification.Builder.setFullScreenIntent(...)`.
- Do not submit a full-screen intent declaration for OnTime unless Play policy
  approval is obtained for a materially different app scope.
- Replace version code 52 in every affected Play track with a new
  policy-compliant bundle whose version code is greater than 52.

## Source Evidence

- `android/app/src/main/AndroidManifest.xml` must not contain
  `android.permission.USE_FULL_SCREEN_INTENT`.
- `android/app/src/main/kotlin/club/devkor/ontime/NativeAlarmReceiver.kt` must
  post alarm notifications without `setFullScreenIntent(...)`.
- `docs/Android-Manifest-Permissions.md` records the removed permission and the
  remaining app-owned Android permissions.

## Play Console Remediation

Use the policy issue page's "How to fix" flow:

1. Build and upload a new signed Android App Bundle with a version code greater
   than 52.
2. Add the new compliant bundle to each affected testing or production track.
3. Ensure the noncompliant version code 52 is under "Not included" for the new
   release.
4. Save, review, and roll out the replacement release to fully deactivate the
   noncompliant bundle.
5. Re-check App bundle explorer and confirm version code 52 is inactive and has
   0 releases.

## QA Checklist

Record the app version, Android device model, Android version, build type, and
timestamp for each run.

- User-scheduled alarm fires while the app is backgrounded and posts an alarm
  notification.
- Tapping the alarm notification opens `AlarmRingingActivity`.
- Tapping "Start preparing" opens the schedule preparation flow for the alarm
  schedule.
- Tapping "Dismiss" clears the alarm notification.
- Generic push notifications do not open `AlarmRingingActivity`.
- Preparation-step notifications do not open `AlarmRingingActivity`.
- Android 13+ notification-denied state does not post alarm notifications.
- Android 12+ exact-alarm-denied state does not schedule a native exact alarm
  and follows the documented permission/fallback behavior.
