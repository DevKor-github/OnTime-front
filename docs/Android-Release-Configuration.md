# Android Release Configuration

Android release builds must include the production Firebase client config so Firebase Core and Firebase Messaging initialize consistently.

## Required CI Secret

- `ANDROID_GOOGLE_SERVICES_JSON_B64`: base64-encoded contents of the production Android `google-services.json` for Firebase project `ontime-c63f1`.

The release verification workflow decodes this secret to `android/app/src/release/google-services.json` before running the Android release build. Generated `google-services.json` files are ignored and must not be committed.

## Google Play Internal Testing Deploy

Use the `Android Play Internal Deploy` GitHub Actions workflow to build a signed
Android App Bundle and upload it to the Google Play Internal Testing track as a
draft release. The workflow is manual-only and must be dispatched from `main`.

Configure a GitHub environment named `release` with required reviewers before
using the workflow. Store these environment secrets there:

- `ANDROID_GOOGLE_SERVICES_JSON_B64`: base64-encoded production Android
  Firebase config.
- `ANDROID_UPLOAD_KEYSTORE_B64`: base64-encoded Google Play upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`: upload keystore password.
- `ANDROID_KEY_ALIAS`: upload key alias.
- `ANDROID_KEY_PASSWORD`: upload key password.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: raw service-account JSON for the Google
  Play Developer API.

Store this environment variable in `release`:

- `REST_API_URL`: production API base URL passed to Flutter with
  `--dart-define`.

The deploy workflow runs package install, code generation, generated-file drift
checking, analysis, tests, and then `flutter build appbundle --release`. It
uploads the signed `.aab` as a 14-day GitHub Actions artifact and creates a
draft release on Google Play Internal Testing. If the optional release notes
input is empty, the workflow uploads without custom release notes.

The workflow is split into a build/check job and a Play upload job. If the
upload fails after the `.aab` artifact is built, use GitHub Actions' rerun
failed jobs option to retry only the upload job.

`pubspec.yaml` remains the source of truth for `version: major.minor.patch+build`.
Before dispatching the workflow, bump the build number so it is greater than
every previously uploaded Google Play build for `club.devkor.ontime`. Duplicate
build numbers fail during the Google Play upload step.

## Local Release Build

Create the release source-set config before building:

```sh
mkdir -p android/app/src/release
base64 --decode android-google-services.json.b64 > android/app/src/release/google-services.json
flutter build appbundle --release --dart-define=REST_API_URL=<api-url>
```

On macOS, use `base64 -D` instead of `base64 --decode`.

Debug/local builds may run without Android Firebase config. Release builds fail clearly if `android/app/src/release/google-services.json`, `android/app/google-services.json`, or `android/app/src/google-services.json` is missing.

## Verification

Use the `Android Release Verification` GitHub Actions workflow to confirm CI can reproduce the release build with the configured secret. For production readiness, also install a real Android release build and verify Firebase initializes and FCM token registration reaches the backend.
