# Issue 442 Android Manifest Permission Audit Plan

## Scope

Audit Android manifest permissions for release readiness under parent track #465.
This issue covers only manifest permission inventory, permission justification,
and merged-manifest verification for Android.

## Files Likely Touched

- `docs/Android-Manifest-Permissions.md`
- `docs/Release-Checklist.md`

No Android manifest permission removal is planned unless the audit finds an
unused release permission.

## Implementation Approach

1. Review `android/app/src/main/AndroidManifest.xml` for release permissions.
2. Review `android/app/src/debug/AndroidManifest.xml` and
   `android/app/src/profile/AndroidManifest.xml` for variant-only permissions.
3. Trace each release permission to current native or Flutter behavior.
4. Document the release permission inventory and justification.
5. Link the audit from the release checklist.
6. Run manifest-merge verification and confirm no unexpected sensitive
   permission is introduced by plugins or manifest merge.

## Verification

- `flutter pub get`
- Android merged manifest task, then inspect merged permissions.
- `git diff --check`

## Blockers

None for this issue. A full signed release build may require Firebase and
signing secrets, but manifest merge can be verified without changing release
behavior.

## Explicitly Left Out

- Notification permission UX changes for #443.
- Exact alarm permission UX changes for #444.
- Play Console full-screen intent remediation for #445.
- Device alarm and notification QA for #457.
