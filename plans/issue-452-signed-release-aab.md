# Issue #452 Signed Release AAB Plan

Parent track: #467
Sub-issue: #452 - Build a signed release Android App Bundle

## Current Status

#452 remains externally blocked until all prerequisites are complete and release
secrets are available to the release owner or the protected GitHub Actions
environment.

Prerequisite status checked on 2026-05-10:

- #450 release signing ownership and secret process: closed.
- #451 release Firebase/Google services config process: closed.
- #453 initial production versioning: open, so #452 must not be closed.

The repository already has Gradle checks for release Firebase config and release
signing inputs, plus the `Android Play Internal Deploy` workflow that builds a
signed AAB when the configured environment secrets and variables are present.

## Decision-Complete Plan

1. Wait for #453 to close with the approved public `versionName` and Android
   `versionCode` rule for the first production upload.
2. Confirm the `staging` GitHub environment has these secrets:
   - `ANDROID_GOOGLE_SERVICES_JSON_B64`
   - `ANDROID_UPLOAD_KEYSTORE_B64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
3. Confirm the `staging` GitHub environment has `REST_API_URL` set to the
   approved release-candidate API base URL.
4. From `main`, run the `Android Play Internal Deploy` workflow.
5. Confirm the workflow passes:
   - `flutter pub get`
   - `dart run build_runner build --delete-conflicting-outputs`
   - generated-file drift check
   - `flutter analyze`
   - `flutter test`
   - `flutter build appbundle --release`
6. Record the signed AAB evidence:
   - workflow run URL
   - artifact name: `ontime-android-release-aab`
   - artifact path inside the run: `build/app/outputs/bundle/release/app-release.aab`
   - version name
   - generated Android version code
   - target environment and `REST_API_URL` ownership confirmation
7. Keep #452 open if any required secret, environment variable, versioning
   decision, or Play upload permission is unavailable.

## Local Build Alternative

Use this only when the release owner has local access to the upload keystore,
passwords, production Firebase config, and approved version values:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test

mkdir -p android/app/src/release
base64 --decode android-google-services.json.b64 > android/app/src/release/google-services.json

export ANDROID_KEYSTORE_PATH=/absolute/path/to/ontime-upload.jks
export ANDROID_KEYSTORE_PASSWORD='<keystore-password>'
export ANDROID_KEY_ALIAS=ontime
export ANDROID_KEY_PASSWORD='<key-password>'

flutter build appbundle --release \
  --build-name=<approved version name> \
  --build-number=<approved monotonic Android versionCode> \
  --dart-define=ENV=staging \
  --dart-define=REST_API_URL=<approved release-candidate api url>
```

On macOS, use `base64 -D` instead of `base64 --decode`.

## Handoff Evidence Template

```text
#452 signed AAB evidence
- Workflow run URL:
- Git commit SHA:
- Version name:
- Android version code:
- Build environment: staging
- REST_API_URL owner-confirmed: yes/no
- AAB artifact name: ontime-android-release-aab
- AAB artifact path: build/app/outputs/bundle/release/app-release.aab
- Follow-up issue unblocked: #456
- Remaining blockers, if any:
```

## Out Of Scope

- Choosing or changing the production version; that belongs to #453.
- Creating, rotating, or disclosing signing keys.
- Committing `google-services.json`, keystores, passwords, or generated AABs.
- Verifying Play App Signing fingerprints; that belongs to #454.
- Device smoke testing; that belongs to #456.
