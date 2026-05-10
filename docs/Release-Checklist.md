# Release Checklist

Use this checklist before producing store or production distribution builds for
OnTime.

## Versioning

- Create store candidates from `release/x.y.z` branches and production releases
  from `vX.Y.Z` tags.
- Merge each release branch back into `main` after the production tag is cut so
  release fixes and version bumps do not drift.
- Keep `pubspec.yaml` as the source of truth for the app version.
- Use semantic versioning for the public version name, formatted as
  `major.minor.patch`.
- The first production release is `1.0.0+1`.
- Keep the public version name manual in `pubspec.yaml`.
- For Android Play deploys, CI derives `versionName` from `pubspec.yaml` and
  uses `github.run_number` as the generated `versionCode`; do not open PRs only
  to bump the checked-in build suffix.

## Branch and Environment

- Confirm the candidate branch is named `release/x.y.z` for planned releases or
  `hotfix/x.y.z` for urgent production repairs.
- Confirm final production deployments are triggered from a `vX.Y.Z` tag, not
  directly from `main` or a release branch.
- Use `ENV=staging` for release-candidate QA builds.
- Use `ENV=prod` for tagged production builds.
- Require manual approval before promoting tagged builds to Play Store or App
  Store production.

## Android

- Confirm the application ID is `club.devkor.ontime`.
- Confirm the app label is `OnTime`.
- Review launcher icons in `android/app/src/main/res/mipmap-*`.
- Review `docs/Android-Manifest-Permissions.md` and confirm app-owned release
  manifest permissions are still limited to user-facing notification, exact
  alarm, full-screen alarm, boot restore, and vibration behavior.
- Provide release signing through one of the following secret-free paths:
  - `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and
    `keyPassword`.
  - Environment variables `ANDROID_KEYSTORE_PATH`,
    `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
    `ANDROID_KEY_PASSWORD`.
  - Legacy environment variables `ONTIME_ANDROID_KEYSTORE_PATH`,
    `ONTIME_ANDROID_KEYSTORE_PASSWORD`, `ONTIME_ANDROID_KEY_ALIAS`, and
    `ONTIME_ANDROID_KEY_PASSWORD`.
- Follow `docs/Android-Signing-Setup.md` when creating or configuring the
  upload key.
- Keep keystores, passwords, and `key.properties` out of git.
- Verify the release build fails clearly when signing secrets are missing.

## iOS

- Confirm the bundle identifier is `club.devkor.ontime`.
- Confirm the display name and bundle name are `OnTime`.
- Review the app icon set in `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- Confirm the launch screen, supported orientations, background modes,
  entitlements, and AlarmKit capability declarations match the release target.
- Pass `GOOGLE_RESERVED_CLIENT_ID_IOS` for release/archive builds as documented
  in `docs/iOS-Release-Configuration.md`.

## Web

- Confirm `web/manifest.json` uses the production app name, short name,
  description, icons, theme color, and orientation.
- Confirm `web/index.html` uses the production description, app title, favicon,
  apple mobile web app title, and touch icon.
- Rebuild the web app before deployment.

## Store Metadata

- Confirm the app name, short description, full description, screenshots,
  support contact, privacy policy, and category are ready for the target stores.
- Use `docs/Google-Play-Listing-Copy.md` as the draft source for Google Play
  short and full descriptions until product/design approve final copy.
- Use `docs/Google-Play-Listing-Graphics.md` as the checklist for Play app
  icon, feature graphic, screenshot asset requirements, and launcher-icon
  consistency evidence.
- Track any brand, icon, screenshot, or store copy gaps before submission.

## Content Category and UGC

- Current release audit result (2026-05-09): no UGC is exposed to other users.
  Users can create schedules, schedule notes, preparation steps,
  account profile values, and deletion or feedback text, but the checked app
  routes and API clients do not provide public profiles, shared schedules,
  comments, chat, feeds, uploads, groups, or other user-to-user content surfaces.
- Current restricted-category audit result (2026-05-09): OnTime is a schedule
  preparation, alarm, reminder, and arrival-time planning app. The checked source
  does not implement gambling, betting, regulated finance, trading, lending,
  crypto, medical, adult, or other restricted-category flows.
- Before each store submission, re-check `lib/core/constants/endpoint.dart`, the
  schedule, preparation, authentication, notification, and alarm data sources,
  and user-facing flows for any newly added shared or public content surfaces.
- If user-created content becomes visible to other users, open release-blocking
  issues for reporting, blocking, moderation or abuse handling, Play Data safety,
  and content rating updates before release.
- Keep store category and listing copy aligned with productivity, planner, alarm,
  and reminder functionality unless a future feature and policy review supports a
  different category.
