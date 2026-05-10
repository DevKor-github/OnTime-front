# Issue 446 App Identity Plan

## Goal
Finalize and verify the public app identity for release issue #446 under parent
track #466.

## Context
- Parent issue #466 orders #446 before store-copy, asset, screenshot, and UGC
  audit work.
- Issue #446 is labeled `codex-ready`, has no prerequisites, and asks to lock
  the public identity before the first Play upload.
- The final public name is `OnTime` unless a requested change is documented.
- Android namespace and application ID are already `club.devkor.ontime`.
- Android app label, iOS display/bundle name, web manifest/title, localization
  app name, and release checklist already use `OnTime`.
- The only discovered mismatch is the iOS AlarmKit usage description spelling
  the product as `On Time`.

## Decisions
- Keep the public app name as `OnTime`.
- Keep the Android application ID as `club.devkor.ontime`.
- Treat Play listing screenshots/assets/privacy-policy review as verification
  and handoff context only; final screenshots and listing art are covered by
  later manual sub-issues.
- Fix in-repo naming mismatches that can affect public app metadata or system
  permission text.

## Steps
1. Update iOS release and debug Info.plist AlarmKit usage descriptions from
   `On Time` to `OnTime`.
2. Re-run targeted identity searches across app, platform, docs, and web files.
3. Run static verification relevant to metadata-only changes.
4. Review the diff and commit only #446 files.

## Validation
- `rg -n "On Time|android:label|applicationId|CFBundleDisplayName|CFBundleName|club\.devkor\.ontime" android ios web docs lib pubspec.yaml README.md`
- `flutter analyze`

## Open Questions
- None.
