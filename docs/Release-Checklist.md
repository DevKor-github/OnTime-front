# Release Checklist

Use this checklist before producing store or production distribution builds for
OnTime.

Draft status for #462: this checklist is repo-ready source material, but #462
must stay open until the release build, Play Console, device QA, and pre-launch
prerequisites in #450-#459 settle.

## Release Gate

- Confirm #450 and #451 are complete before attempting signed Android release
  builds.
- Confirm #452 produced or identified the signed Android App Bundle that will be
  tested or submitted.
- Confirm #453 has locked the first production versioning rule.
- Confirm #454 recorded Play App Signing, upload key, SHA-1, and SHA-256
  fingerprints in the appropriate secure or console locations.
- Confirm #455 has checked Play Console developer verification and package
  registration status.
- Confirm #456, #457, #458, and #459 have recorded release smoke test, alarm and
  notification QA, account deletion QA, and pre-launch report results.
- Assign a release owner and backup owner before any Play Console submission.

## Required Verification Commands

Run these commands from the repository root before building or submitting a
release candidate:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build appbundle --release
```

- After code generation, run `git diff --exit-code` or review the diff to
  confirm generated files are intentionally updated.
- For local Android release builds, provide the signing, Firebase, `ENV`, and
  `REST_API_URL` inputs documented in `docs/Android-Release-Configuration.md`
  and `docs/Android-Release-Signing.md`.
- For CI Play uploads, use the `Android Play Internal Deploy` workflow from
  `main`; it runs package install, code generation, generated-file drift
  checking, analysis, tests, AAB build, artifact upload, and internal testing
  draft upload.
- Record any command failure with the failing command, environment, and owner
  before release approval.

## Versioning

- Create store candidates from `release/x.y.z` branches and production releases
  from `vX.Y.Z` tags.
- Merge each release branch back into `main` after the production tag is cut so
  release fixes and version bumps do not drift.
- Keep `pubspec.yaml` as the source of truth for the app version.
- Use semantic versioning for the public version name, formatted as
  `major.minor.patch`.
- The first production release is `1.0.0+1`: public `versionName` `1.0.0`
  with checked-in Flutter build suffix `+1`.
- Keep the public version name manual in `pubspec.yaml`.
- For Android Play deploys, CI derives `versionName` from `pubspec.yaml` and
  uses `github.run_number` as the generated `versionCode`; do not open PRs only
  to bump the checked-in build suffix.
- When uploading manually, choose an Android `versionCode` greater than every
  previously uploaded Play build for `club.devkor.ontime`.

## Generated Files And Dependencies

- Run code generation after changes to Drift tables and DAOs, JSON models,
  Freezed classes, Injectable registrations, Widgetbook annotations, or any
  file that owns generated `*.g.dart`, `*.freezed.dart`, or `*.config.dart`
  output.
- Keep generated Dart outputs in the same PR as the source change that requires
  them.
- Do not commit local release secrets, generated Firebase config files,
  keystores, `android/key.properties`, Play service-account JSON, coverage
  output, or build artifacts.
- Review `pubspec.lock`, native lockfiles, and generated platform files when
  dependencies or plugins change.

## Branch And Environment

- Confirm the candidate branch is named `release/x.y.z` for planned releases or
  `hotfix/x.y.z` for urgent production repairs.
- Confirm final production deployments are triggered from a `vX.Y.Z` tag, not
  directly from `main` or a release branch.
- Use `ENV=staging` for release-candidate QA builds.
- Use `ENV=prod` for tagged production builds.
- Confirm `REST_API_URL` points at the approved release or production API
  environment.
- Require manual approval before promoting tagged builds to Play Store or App
  Store production.

## Android

- Confirm the application ID is `club.devkor.ontime`.
- Confirm the app label is `OnTime`.
- Review launcher icons in `android/app/src/main/res/mipmap-*`.
- Review `docs/Android-Manifest-Permissions.md` and confirm app-owned release
  manifest permissions are still limited to user-facing notification, exact
  alarm, full-screen alarm, boot restore, and vibration behavior.
- Run Android alarm and notification device QA with
  `docs/Android-Alarm-Notification-QA.md` before closing release issue #457.
- Provide release signing through one of the following secret-free paths:
  - `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and
    `keyPassword`.
  - Environment variables `ANDROID_KEYSTORE_PATH`,
    `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
    `ANDROID_KEY_PASSWORD`.
  - Legacy environment variables `ONTIME_ANDROID_KEYSTORE_PATH`,
    `ONTIME_ANDROID_KEYSTORE_PASSWORD`, `ONTIME_ANDROID_KEY_ALIAS`, and
    `ONTIME_ANDROID_KEY_PASSWORD`.
- Follow `docs/Android-Signing-Setup.md` when creating or configuring the upload
  key.
- Keep keystores, passwords, and `key.properties` out of git.
- Verify the release build fails clearly when signing secrets are missing.
- After the signed AAB is uploaded to internal or closed testing, run the Google
  Play pre-launch report and record evidence using
  `docs/Play-Pre-Launch-Report.md` before widening release availability.
- Confirm the release Firebase config is available through
  `ANDROID_GOOGLE_SERVICES_JSON_B64` in CI or
  `android/app/src/release/google-services.json` for local release builds.
- After Play App Signing is enabled, verify Firebase and auth provider
  fingerprint configuration against the final Play App Signing and upload-key
  SHA-1/SHA-256 values.
- Record the generated `.aab` path, build name, build number, workflow run, and
  commit SHA.

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

## Store Metadata And Screenshots

- Confirm the app name, short description, full description, screenshots,
  support contact, privacy policy, category, and release notes are ready for the
  target stores.
- Use `docs/Google-Play-Listing-Copy.md` as the draft source for Google Play
  short and full descriptions until product/design approve final copy.
- Use `docs/Google-Play-Listing-Graphics.md` as the checklist for Play app
  icon, feature graphic, screenshot asset requirements, and launcher-icon
  consistency evidence.
- Use `docs/Google-Play-Data-Safety.md` as the source-backed worksheet for
  Play Data safety answers after privacy, backend deletion, account deletion
  URL, and final SDK/provider prerequisites are resolved.
- Track any brand, icon, screenshot, or store copy gaps before submission.
- Verify screenshots against the release candidate build, not older debug or
  mock screens.
- Re-check screenshot, feature graphic, app title, and listing copy after any
  visible UI, brand, onboarding, permission, account, alarm, notification, or
  privacy flow change.
- Keep screenshots free of personal data, test credentials, debug banners, and
  staging-only content.
- Track any brand, icon, screenshot, or store copy gap before submission.

## Privacy Policy And Data Safety Triggers

Review and update privacy policy, Play Data safety, account deletion, and store
disclosures before submission when any release change adds, removes, or changes:

- Personal data collection, including account identifiers, profile fields,
  schedule content, preparation steps, locations, feedback text, deletion
  requests, device identifiers, push tokens, analytics, diagnostics, or logs.
- Data sharing with a new backend, Firebase project, auth provider, analytics
  provider, crash reporting provider, notification service, support tool, or
  other third party.
- Authentication, account deletion, sign-out, data export, retention, or backend
  deletion behavior.
- Notification, exact alarm, full-screen intent, boot restore, background
  execution, location, photos, contacts, camera, microphone, health, finance, or
  other permission-sensitive behavior.
- Store listing claims about privacy, security, notifications, alarms, account
  control, or data deletion.
- User-created content that becomes visible to other users.
- Age range, target audience, ads, content rating, restricted category, or
  regulated-content answers.

If any trigger applies, block release approval until the release owner records
which privacy policy section, Play Data safety answer, Play declaration, or
store listing field was reviewed or changed.

## Content Category And UGC

- Current release audit result (2026-05-09): no UGC is exposed to other users.
  Users can create schedules, schedule notes, preparation steps, account profile
  values, and deletion or feedback text, but the checked app routes and API
  clients do not provide public profiles, shared schedules, comments, chat,
  feeds, uploads, groups, or other user-to-user content surfaces.
- Current restricted-category audit result (2026-05-09): OnTime is a schedule
  preparation, alarm, reminder, and arrival-time planning app. The checked source
  does not implement gambling, betting, regulated finance, trading, lending,
  crypto, medical, adult, or other restricted-category flows.
- Before each store submission, re-check `lib/core/constants/endpoint.dart`, the
  schedule, preparation, authentication, notification, and alarm data sources,
  and user-facing flows for any newly added shared or public content surfaces.
- If user-created content becomes visible to other users, open release-blocking
  issues for reporting, blocking, moderation or abuse handling, Play Data
  safety, and content rating updates before release.
- Keep store category and listing copy aligned with productivity, planner,
  alarm, and reminder functionality unless a future feature and policy review
  supports a different category.

## Play Console Declarations

- Confirm Play App Signing and certificate fingerprints before final Firebase
  or auth provider release verification.
- Confirm developer verification and package registration status in Play Console
  before the first production submission.
- Confirm Data safety, privacy policy URL, account deletion URL, content rating,
  target audience, app category, app access, ads, permissions, full-screen
  intent, and background activity declarations match the submitted build.
- Keep Play Console declaration evidence in the release tracking thread or
  secure shared folder, not in source control when it contains account,
  reviewer, or console-private data.
- If Play review rejects the app, use
  `docs/Play-Review-Rejection-Playbook.md` before resubmitting or appealing.

## Device QA And Pre-launch

- Install the release build through internal testing or a release-equivalent
  path.
- Test first launch, login, logout, schedule create/edit/delete, My Page, and
  privacy policy link.
- Test notification permission granted and denied states.
- Test exact alarm permission granted and denied states.
- Test alarm firing, full-screen alarm UI, fallback notification behavior, and
  cancellation.
- Test boot restore behavior after device restart where practical.
- Test account deletion end to end with a release test account.
- Record device model, Android version, app version, build number, API
  environment, result, and owner.
- Run or review the Play Console pre-launch report before wider rollout.
- Fix release-blocking crashes, ANRs, policy warnings, severe accessibility
  warnings, install failures, sign-in blockers, deletion failures, missed alarms,
  Firebase initialization failures, and backend token registration failures.

## Rollout Monitoring

- Follow `docs/Release-Rollout-Monitoring.md` for release owner assignment,
  staged rollout gates, monitoring locations, pause criteria, and first 24-hour
  and first 7-day checks.
- Record version name, generated build number, track, rollout percentage,
  release owner, backup owner, dashboards checked, decision, and next check time
  at every rollout decision.
- Do not widen rollout while Play review, policy email, Android Vitals,
  Firebase, backend monitoring, ratings, reviews, tester feedback, or support
  reports show an unresolved release-caused blocker.

## Release Evidence Template

```md
Release:
Version name:
Build number:
Commit SHA:
Workflow run:
Artifact path:
Track:
Release owner:
Backup owner:

Commands:
- flutter pub get:
- dart run build_runner build --delete-conflicting-outputs:
- flutter analyze:
- flutter test:
- flutter build appbundle --release:

Generated files reviewed:
Signing and Firebase config verified:
Play App Signing fingerprints verified:
Privacy policy/Data safety reviewed:
Store metadata/screenshots reviewed:
Device QA completed:
Pre-launch report reviewed:
Rollout monitoring note created:

Open risks:
Decision:
```
