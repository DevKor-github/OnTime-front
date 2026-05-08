# Release Checklist

Use this checklist before producing store or production distribution builds for
OnTime.

## Versioning

- Keep `pubspec.yaml` as the source of truth for the app version.
- Use semantic versioning for the public version name, formatted as
  `major.minor.patch`.
- The first production release is `1.0.0+1`.
- Keep the public version name manual in `pubspec.yaml`.
- For Android Play deploys, CI derives `versionName` from `pubspec.yaml` and
  uses `github.run_number` as the generated `versionCode`; do not open PRs only
  to bump the checked-in build suffix.

## Android

- Confirm the application ID is `club.devkor.ontime`.
- Confirm the app label is `OnTime`.
- Review launcher icons in `android/app/src/main/res/mipmap-*`.
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
- Track any brand, icon, screenshot, or store copy gaps before submission.
